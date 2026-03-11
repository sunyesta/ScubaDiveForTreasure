local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

local Player = Players.LocalPlayer

local ForestEntrance = Component.new({
	Tag = "ForestEntrance",
	Ancestors = { Workspace },
})

function ForestEntrance:Construct()
	self._Trove = Trove.new()
end

function ForestEntrance:Start()
	local hitbox = self.Instance
	hitbox.Touched:Connect(function(hit)
		if PlayerUtils.GetPlayerFromPart(hit) == Player then
			PlayerComm:EnterForest()
		end
	end)
end

function ForestEntrance:Stop()
	self._Trove:Clean()
end

return ForestEntrance
