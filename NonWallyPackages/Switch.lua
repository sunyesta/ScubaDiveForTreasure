--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Define the Internal Type for the Switch object
export type Switch = {
	Observe: (self: Switch, callback: (trove: any) -> ()) -> any,
	Set: (self: Switch, toggle: boolean) -> (),
	Get: (self: Switch) -> boolean,
	Destroy: (self: Switch) -> (),
	_Trove: any,
	_Firing: any,
}

local Switch = {}
Switch.__index = Switch

function Switch.new(toggle)
	local self = setmetatable({}, Switch)

	self._Trove = Trove.new()
	self._Firing = Property.new(toggle)

	return self
end

function Switch:Observe(callback)
	local firingTrove = self._Trove:Extend()
	return self._Trove:Add(self._Firing:Observe(function(firing)
		firingTrove:Clean()
		if firing then
			callback(firingTrove)
		end
	end))
end

function Switch:Set(toggle)
	self._Firing:Set(toggle)
end

function Switch:Get()
	return self._Firing:Get()
end

function Switch:Destroy()
	self._Trove:Destroy()
end

return Switch
