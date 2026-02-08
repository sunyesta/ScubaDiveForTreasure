local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
-------------------------------------------------------------------------------
-- COMPONENTS (Body & Aim)
-------------------------------------------------------------------------------
-- Base class for components to modify camera state
local ComponentBase = {}
ComponentBase.__index = ComponentBase

function ComponentBase.new()
	local self = setmetatable({}, ComponentBase)
	self._trove = Trove.new()
	return self
end

function ComponentBase:Mutate(vcam, state, dt)
	-- Override me
end

function ComponentBase:Destroy()
	self._trove:Clean()
end

return ComponentBase
