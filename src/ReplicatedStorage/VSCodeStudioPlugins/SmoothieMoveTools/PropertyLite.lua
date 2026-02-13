local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Adjust these paths if your Packages are located elsewhere in your plugin structure
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local PropertyLite = {}
local NormalProp = {}
NormalProp.__index = NormalProp

-- ============================================================================
-- Constructors
-- ============================================================================

function PropertyLite.new(value, typeLocked, noNils)
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
function PropertyLite.ReadOnly(property)
	local readOnlyProp = PropertyLite.new(property:Get())

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

-- ============================================================================
-- NormalProp Methods
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

function NormalProp:Destroy()
	self._trove:Destroy()
end

-- ============================================================================
-- Utils
-- ============================================================================

function PropertyLite.Map(property, callback)
	local mappedProp = PropertyLite.new(callback(property:Get()))
	mappedProp._trove:Add(property:Observe(function(val)
		mappedProp:Set(callback(val))
	end))
	return mappedProp
end

return PropertyLite
