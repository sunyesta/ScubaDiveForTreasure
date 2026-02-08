-- Property.lua (Don't remove this comment!)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Promise = require(ReplicatedStorage.Packages.Promise)

local Property = {}
Property.__index = Property

-- value - initial value of property
-- typeLocked - if true, value's type can not be changed
function Property.new(value, typeLocked, noNils)
	local self = setmetatable({}, Property)

	if typeLocked == nil and value ~= nil then
		typeLocked = true
	end
	assert((typeLocked and value ~= nil) or not typeLocked, "can not be typelocked and have nil inital value")

	if typeLocked then
		self.Type = typeof(value)
	end

	if type(value) == "table" then
		value = table.clone(value)
	end

	self._Trove = Trove.new()

	self.Value = value
	self.NoNils = noNils
	self.Changed = Signal.new()
	self.DebugFunc = nil
	self._commProp = nil -- Reference to underlying CommProperty if applicable
	self._playerChanged = nil -- Lazy-loaded signal for SetFor changes
	return self
end

function Property.ReadOnly(property)
	local self = setmetatable({}, Property)

	self.Value = property.Value
	self.Changed = Signal.new()
	self._Trove = Trove.new()

	property.Changed:Connect(function(value)
		self.Value = value
		self.Changed:Fire(value)
	end)

	self.Set = function()
		error("Can't set read-only property!")
	end

	return self
end

function Property.NewBoundToCommProperty(commProperty)
	assert(RunService:IsClient(), "only works on client")
	return Promise.new(function(resolve)
		local property = Property.new()

		property._Trove:Add(commProperty:Observe(function(val)
			property:Set(val)
			resolve(property)
		end))
	end)
end

function Property.BindToAttribute(instance, attributeName, defaultValue, readOnly)
	assert(((not defaultValue) and readOnly) or not readOnly, "default value can't be set for readonly")
	local initialValue = defaultValue or instance:GetAttribute(attributeName)
	local property = Property.new(initialValue)

	-- Update property when attribute changes
	property._Trove:Add(instance:GetAttributeChangedSignal(attributeName):Connect(function()
		-- Use Property.Set directly to bypass the read-only check/override if present
		Property.Set(property, instance:GetAttribute(attributeName))
	end))

	if readOnly then
		property.Set = function()
			error("Cannot set read-only property bound to attribute: " .. attributeName)
		end
	else
		-- Update attribute when property changes
		property._Trove:Add(property.Changed:Connect(function(newValue)
			instance:SetAttribute(attributeName, newValue)
		end))
	end

	return property
end

function Property.CreateCommProperty(serverComm, propertyName, initialValue)
	local property = Property.new(initialValue)
	local commProp = serverComm:CreateProperty(propertyName, initialValue)
	property._commProp = commProp

	property._Trove:Add(property.Changed:Connect(function(val)
		commProp:Set(val)
	end))

	return property
end

function Property:Destroy()
	self._Trove:Clean()
	self.Value = nil
	table.freeze(self)
end

function Property:SetDebugFunc(func)
	self.DebugFunc = func
end

function Property:Get()
	return self.Value
end

function Property:Set(value)
	if self.Type then
		assert(value == nil or self.Type == typeof(value), "type must be " .. self.Type .. " but is " .. typeof(value))
	end
	if self.NoNils then
		assert(value ~= nil, "val can't be nil")
	end

	if self.DebugFunc then
		self.DebugFunc(value)
	end

	if type(value) == "table" then
		value = table.clone(value)
	end

	if self.Value == value then
		return
	end

	self.Value = value
	self.Changed:Fire(value)
end

-- Sets the value for a specific player (Client/Network only)
function Property:SetFor(player, value)
	if self._commProp then
		self._commProp:SetFor(player, value)
		if self._playerChanged then
			self._playerChanged:Fire(player, value)
		end
	else
		warn("SetFor called on a property not bound to a CommProperty: " .. tostring(self))
	end
end

-- Gets the value for a specific player (Client/Network only)
function Property:GetFor(player)
	if self._commProp then
		return self._commProp:GetFor(player)
	else
		warn("GetFor called on a property not bound to a CommProperty: " .. tostring(self))
		return nil
	end
end

-- Observes the value for a specific player (Client/Network only)
function Property:ObservePlayer(player, callback)
	if not self._commProp then
		warn("ObservePlayer called on a property not bound to a CommProperty: " .. tostring(self))
		return function() end
	end

	if not self._playerChanged then
		self._playerChanged = self._Trove:Add(Signal.new())
	end

	callback(self:GetFor(player))

	local connection = self._playerChanged:Connect(function(plr, value)
		if plr == player then
			callback(value)
		end
	end)

	return function()
		connection:Disconnect()
	end
end

function Property:Observe(callback)
	callback(self.Value)

	local connection = self.Changed:Connect(function(value)
		callback(value)
	end)

	return function()
		connection:Disconnect()
	end
end

function Property:Append(value)
	local list = self:Get()
	assert(typeof(list) == "table", "must be a table with numerical keys")

	table.insert(list, value)
	self:Set(list)
end

function Property:SetKey(key, value)
	local map = self:Get()
	assert(typeof(map) == "table", "must be a table map")

	map[key] = value
	self:Set(map)
end

function Property:GetKey(key)
	local map = self:Get()
	assert(typeof(map) == "table", "must be a table map")

	return map[key]
end

function Property:IncrementKey(key, amount, deleteKeyOnZero)
	local map = self:Get()
	assert(typeof(map) == "table", "must be a table map")

	map[key] = map[key] or 0

	map[key] += amount
	if deleteKeyOnZero and map[key] == 0 then
		map[key] = nil
	end

	self:Set(map)
end

function Property:Equals(value)
	return self:Get() == value
end

function Property:WaitForTrue()
	return Promise.try(function()
		if self:Get() then
			return
		end
		local isTrue = Signal.new()
		local trove = Trove.new()
		trove:Add(self.Changed:Connect(function(value)
			if value then
				isTrue:Fire()
				trove:Clean()
			end
		end))
		isTrue:Wait()
	end)
end

function Property:WaitForTrueFor(player)
	return Promise.try(function()
		if self:GetFor(player) then
			return
		end

		if not self._playerChanged then
			self._playerChanged = self._Trove:Add(Signal.new())
		end

		local isTrue = Signal.new()
		local trove = Trove.new()
		trove:Add(self._playerChanged:Connect(function(plr, val)
			if plr == player and val then
				isTrue:Fire()
				trove:Clean()
			end
		end))
		isTrue:Wait()
	end)
end

return Property
