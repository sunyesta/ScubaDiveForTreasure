local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local DefaultValue = require(ReplicatedStorage.NonWallyPackages.DefaultValue)
-- modification of https://devforum.roblox.com/t/debounce-module/1941502

local Debounce = {}
Debounce.__index = Debounce

-- startReady defaults to true
function Debounce.new(autoReadyTimer)
	assert(autoReadyTimer ~= nil, "autoReadyTimer is required")

	local self = setmetatable({}, Debounce)
	self._Trove = Trove.new()
	self._AutoReadyTimer = autoReadyTimer
	self._LastUsed = 0

	return self
end

function Debounce:Start()
	if not self.IsReady:Get() then
		return false
	end

	self.IsReady:Set(false)
	return true
end

function Debounce:Destroy()
	self._Trove:Clean()
end

function Debounce:IsReady()
	return time() - self._LastUsed >= self._AutoReadyTimer
end

-- returns if useage was successful
function Debounce:Use()
	if self:IsReady() then
		self._LastUsed = time()
		return true
	else
		return false
	end
end

return Debounce
