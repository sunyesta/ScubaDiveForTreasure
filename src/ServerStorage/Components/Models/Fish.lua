local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)
local MathUtils = require(ReplicatedStorage.NonWallyPackages.MathUtils)

local FishServer = Component.new({
	Tag = "Fish",
	Ancestors = { Workspace },
})

function FishServer:Construct()
	self._Trove = Trove.new()
	self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm"))

	self.MovementPlaneOrigin = World2DUtils.DefaultPlaneOrigin
	self.MovementPlaneNormal = World2DUtils.DefaultPlaneNormal

	self._StartPosition = self.Instance:GetPivot().Position

	self.Instance:SetAttribute("RandomSeed", MathUtils.GetRandomSeed())
end

function FishServer:Start() end

function FishServer:Stop()
	self._Trove:Clean()
end

return FishServer
