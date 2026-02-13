local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencies (Assumed based on old code)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Promise = require(ReplicatedStorage.Packages.Promise)

local Property = {}

-- Class Definitions
local NormalProp = {}
NormalProp.__index = NormalProp

local CommProp = {}
CommProp.__index = CommProp

local PlayerCommProp = {}
PlayerCommProp.__index = PlayerCommProp

-- Expose Classes
Property.NormalProp = NormalProp
Property.CommProp = CommProp
Property.PlayerCommProp = PlayerCommProp

Property.READ_ONLY = "PROPERTY_READ_ONLY"

-- ============================================================================
-- Constructors
-- ============================================================================

-- Returns a NormalProp
function Property.new(value, typeLocked, noNils)
	local self = setmetatable({}, NormalProp)

	-- Type Locking Logic
	if typeLocked == nil and value ~= nil then
		typeLocked = true
	end
	assert((typeLocked and value ~= nil) or not typeLocked, "can not be typelocked and have nil initial value")

	if typeLocked then
		self._type = typeof(value)
	end

	if type(value) == "table" then
		value = table.clone(value)
	end

	self._trove = Trove.new()
	self._value = value
	self._noNils = noNils
	self._changed = self._trove:Add(Signal.new())

	return self
end

-- Returns a NormalProp that can't be written to
function Property.ReadOnly(property)
	local readOnlyProp = Property.new(property:Get())

	-- Sync from source property
	readOnlyProp._trove:Add(property:Observe(function(val)
		-- Access internal state to bypass the ReadOnly Set check we are about to add
		if readOnlyProp._value ~= val then
			readOnlyProp._value = val
			readOnlyProp._changed:Fire(val)
		end
	end))

	-- Disable public Set
	readOnlyProp.Set = function()
		error("Can't set read-only property!")
	end

	return readOnlyProp
end

-- Returns a NormalProp. If defaultValue == Property.READ_ONLY then property is readonly
function Property.BindToAttribute(instance, attributeName, defaultValue)
	local isReadOnly = (defaultValue == Property.READ_ONLY)

	local initialValue
	if isReadOnly then
		initialValue = instance:GetAttribute(attributeName)
	else
		initialValue = defaultValue or instance:GetAttribute(attributeName)
		-- Set default if attribute is missing and we have a default
		if instance:GetAttribute(attributeName) == nil and defaultValue ~= nil then
			instance:SetAttribute(attributeName, defaultValue)
		end
	end

	local prop = Property.new(initialValue)

	-- Sync Attribute -> Prop
	prop._trove:Add(instance:GetAttributeChangedSignal(attributeName):Connect(function()
		local attrVal = instance:GetAttribute(attributeName)
		if prop:Get() ~= attrVal then
			-- Update internal value directly to support ReadOnly mode
			prop._value = attrVal
			prop._changed:Fire(attrVal)
		end
	end))

	if isReadOnly then
		prop.Set = function()
			error("Cannot set read-only property bound to attribute: " .. attributeName)
		end
	else
		-- Sync Prop -> Attribute (Two-way bind)
		prop._trove:Add(prop:Observe(function(val)
			if instance:GetAttribute(attributeName) ~= val then
				instance:SetAttribute(attributeName, val)
			end
		end))
	end

	return prop
end

-- Returns a NormalProp bound to a specific property of an Instance
function Property.BindToInstanceProperty(instance, instancePropertyName, defaultValue)
	local isReadOnly = (defaultValue == Property.READ_ONLY)

	local initialValue
	if isReadOnly then
		initialValue = instance[instancePropertyName]
	else
		-- If defaultValue is provided, use it as the source of truth initially
		if defaultValue ~= nil then
			initialValue = defaultValue
			if instance[instancePropertyName] ~= defaultValue then
				instance[instancePropertyName] = defaultValue
			end
		else
			initialValue = instance[instancePropertyName]
		end
	end

	local prop = Property.new(initialValue)

	-- Sync Instance -> Prop
	prop._trove:Add(instance:GetPropertyChangedSignal(instancePropertyName):Connect(function()
		local newVal = instance[instancePropertyName]
		if prop:Get() ~= newVal then
			-- Update internal value directly to support ReadOnly mode and avoid recursive loops
			prop._value = newVal
			prop._changed:Fire(newVal)
		end
	end))

	if isReadOnly then
		prop.Set = function()
			error("Cannot set read-only property bound to instance property: " .. instancePropertyName)
		end
	else
		-- Sync Prop -> Instance (Two-way bind)
		prop._trove:Add(prop:Observe(function(val)
			if instance[instancePropertyName] ~= val then
				instance[instancePropertyName] = val
			end
		end))
	end

	return prop
end

-- Returns a NormalProp bound to a CommProperty
-- YEILDS
function Property.BindToCommProperty(commProperty)
	assert(RunService:IsClient(), "only works on client")
	assert(commProperty, "Property.BindToCommProperty: 'commProperty' argument is nil. Check your Comm setup.")

	return Promise.new(function(resolve)
		-- 1. Wait for the initial data to arrive from the server
		commProperty:OnReady():expect()

		-- 2. Create the property with the now-guaranteed value
		local prop = Property.new(commProperty:Get())

		-- 3. Set up the observation for future changes
		prop._trove:Add(commProperty.Changed:Connect(function(val)
			prop:Set(val)
		end))

		resolve(prop)
	end):expect()
end

-- Returns a CommProp
function Property.CreateCommProperty(serverComm, propertyName, initialValue)
	local self = setmetatable({}, CommProp)

	-- Create internal NormalProp to handle state and signals
	self._prop = Property.new(initialValue)
	self._commProp = serverComm:CreateProperty(propertyName, initialValue)

	-- Sync: Prop -> Comm
	self._prop:Observe(function(val)
		self._commProp:Set(val)
	end)

	return self
end

-- Returns a PlayerCommProp
function Property.CreatePlayerCommProperty(serverComm, propertyName, initialValue)
	local self = setmetatable({}, PlayerCommProp)

	self._commProp = serverComm:CreateProperty(propertyName, initialValue)
	self._trove = Trove.new()
	self._playerSignals = {} -- [Player] = Signal
	self._allChanged = self._trove:Add(Signal.new())

	return self
end

-- ============================================================================
-- NormalProp
-- ============================================================================

function NormalProp:Get()
	return self._value
end

function NormalProp:Set(value)
	if self._type then
		assert(
			value == nil or typeof(value) == self._type,
			"type must be " .. self._type .. " but is " .. typeof(value)
		)
	end
	if self._noNils then
		assert(value ~= nil, "val can't be nil")
	end

	if type(value) == "table" then
		value = table.clone(value)
	end

	if self._value == value then
		return
	end

	self._value = value
	self._changed:Fire(value)
end

function NormalProp:Observe(callback)
	task.spawn(callback, self._value)
	return self._changed:Connect(callback)
end

function NormalProp:WaitForTrue()
	return Promise.new(function(resolve, _, onCancel)
		if self:Get() then
			resolve()
			return
		end

		local connection
		connection = self._changed:Connect(function(value)
			if value then
				connection:Disconnect()
				resolve()
			end
		end)

		onCancel(function()
			connection:Disconnect()
		end)
	end)
end

function NormalProp:Destroy()
	self._trove:Destroy()
end

-- ============================================================================
-- CommProp
-- ============================================================================

function CommProp:Get()
	return self._prop:Get()
end

function CommProp:Set(value)
	-- This will trigger the observer in constructor which syncs to commProp
	self._prop:Set(value)
end

function CommProp:Observe(callback)
	return self._prop:Observe(callback)
end

function CommProp:WaitForTrue()
	return self._prop:WaitForTrue()
end

function CommProp:Destroy()
	self._prop:Destroy()
end

-- ============================================================================
-- PlayerCommProp
-- ============================================================================

function PlayerCommProp:GetFor(player)
	return self._commProp:GetFor(player)
end

function PlayerCommProp:SetFor(player, value)
	self._commProp:SetFor(player, value)

	-- Fire generic signal
	self._allChanged:Fire(player, value)

	-- Fire specific player signal
	local pSig = self._playerSignals[player]
	if pSig then
		pSig:Fire(value)
	end
end

function PlayerCommProp:ObserveFor(player, callback)
	local initial = self:GetFor(player)
	task.spawn(callback, initial)

	if not self._playerSignals[player] then
		self._playerSignals[player] = self._trove:Add(Signal.new())
	end

	return self._playerSignals[player]:Connect(callback)
end

-- callback(player, value)
function PlayerCommProp:ObserveAll(callback)
	return self._allChanged:Connect(callback)
end

function PlayerCommProp:WaitForTrueFor(player)
	return Promise.new(function(resolve, _, onCancel)
		if self:GetFor(player) then
			resolve()
			return
		end

		if not self._playerSignals[player] then
			self._playerSignals[player] = self._trove:Add(Signal.new())
		end

		local connection
		connection = self._playerSignals[player]:Connect(function(value)
			if value then
				connection:Disconnect()
				resolve()
			end
		end)

		onCancel(function()
			connection:Disconnect()
		end)
	end)
end

function PlayerCommProp:Destroy()
	self._trove:Destroy()
	self._playerSignals = nil
end

-- ============================================================================
-- Utils
-- ============================================================================
local Utils = {}
Property.Utils = Utils

function Utils.Equals(property, value)
	if type(property) == "table" and property.Get then
		return property:Get() == value
	end
	return false
end

-- Increments the property by an amount, requires stored value to be a number
function Utils.IncrementValue(property, amount)
	local current = property:Get()
	if type(current) == "number" then
		property:Set(current + amount)
	else
		warn("Cannot increment non-number property")
	end
end

-- callback(value) -> new value
-- Returns a new NormalProp that maps the value of the original property
function Utils.Map(property, callback)
	local mappedProp = Property.new(callback(property:Get()))

	mappedProp._trove:Add(property:Observe(function(val)
		mappedProp:Set(callback(val))
	end))

	return mappedProp
end

return Property
