local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

local Player = Players.LocalPlayer

local ForestPath = Component.new({
	Tag = "ForestPath",
	Ancestors = { Workspace },
})

function ForestPath:Construct()
	self._Trove = Trove.new()
	self._PathID = Property.BindToAttribute(self.Instance, "PathID")
end

function ForestPath:Start()
	local hitbox = self.Instance
	hitbox.Touched:Connect(function()
		PlayerComm:UseForestPath(self._PathID:Get())
	end)
end

function ForestPath:Stop()
	self._Trove:Clean()
end

return ForestPath
