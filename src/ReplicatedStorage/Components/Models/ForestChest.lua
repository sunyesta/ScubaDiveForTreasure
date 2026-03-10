local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local CreateProximityPrompt = require(ReplicatedStorage.Common.Modules.GameUtils.CreateProximityPrompt)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

local Player = Players.LocalPlayer

local ForestChestClient = Component.new({
	Tag = "ForestChestClient",
	Ancestors = { Workspace },
})

function ForestChestClient:Construct()
	self._Trove = Trove.new()
end

function ForestChestClient:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))

	self._Trove:Add(partStreamable:Observe(function(RootPart, loadedTrove)
		if RootPart then
			self:Loaded(RootPart, loadedTrove)
		end
	end))
end

function ForestChestClient:Stop()
	self._Trove:Clean()
end

function ForestChestClient:Loaded(RootPart, trove)
	local ProximityPrompt = CreateProximityPrompt(RootPart)
	local chestItems = PlayerComm.GetForestChestItems()

	ProximityPrompt.Triggered:Connect(function() end)
end

return ForestChestClient
