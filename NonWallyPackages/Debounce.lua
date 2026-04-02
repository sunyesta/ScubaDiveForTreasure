--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Defines the shape of our Debounce class for Luau strict typing
export type Debounce = {
	_Trove: any,
	_AutoReadyTimer: number,
	_LastUsed: number,

	IsReady: (self: Debounce) -> boolean,
	Use: (self: Debounce) -> boolean,
	Start: (self: Debounce) -> boolean,
	Destroy: (self: Debounce) -> (),
	SetAutoReadyTimer: (self: Debounce, autoReadyTimer: number) -> (),
}

local Debounce = {}
Debounce.__index = Debounce

--[=[
	Creates a new Debounce object.
	
	@param autoReadyTimer number -- The cooldown time in seconds.
	@return Debounce
]=]
function Debounce.new(autoReadyTimer: number): Debounce
	assert(type(autoReadyTimer) == "number", "autoReadyTimer is required and must be a number")

	local self = setmetatable({}, Debounce)
	self._Trove = Trove.new()
	self._AutoReadyTimer = autoReadyTimer
	self._LastUsed = 0

	return self :: any
end

--[=[
	Sets a new cooldown time for the debounce.
	
	@param autoReadyTimer number -- The new cooldown time in seconds.
]=]
function Debounce:SetAutoReadyTimer(autoReadyTimer: number)
	assert(type(autoReadyTimer) == "number", "autoReadyTimer must be a number")
	self._AutoReadyTimer = autoReadyTimer
end

--[=[
	Checks if the debounce timer has finished cooling down.
	
	@return boolean -- True if the action is ready to be performed again.
]=]
function Debounce:IsReady(): boolean
	-- os.clock() is highly precise and better for cooldowns than time()
	return (os.clock() - self._LastUsed) >= self._AutoReadyTimer
end

--[=[
	Attempts to use the debounce. If it is ready, the cooldown is reset.
	
	@return boolean -- True if usage was successful, false if it is still on cooldown.
]=]
function Debounce:Use(): boolean
	if self:IsReady() then
		self._LastUsed = os.clock()
		return true
	else
		return false
	end
end

--[=[
	An alias for :Use(). Starts the cooldown if the debounce is ready.
	
	@return boolean -- True if successfully started.
]=]
function Debounce:Start(): boolean
	return self:Use()
end

--[=[
	Cleans up the debounce object, firing the Trove to prevent memory leaks.
]=]
function Debounce:Destroy()
	self._Trove:Clean()
	setmetatable(self :: any, nil)
end

return Debounce
