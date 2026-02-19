local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local Treasure = require(ReplicatedStorage.Common.Components.Models.Treasure)

local Player = Players.LocalPlayer

local TreasureDeposit = Component.new({
	Tag = "TreasureDeposit",
	Ancestors = { Workspace },
})

function TreasureDeposit:Construct()
	self._Trove = Trove.new()
end

function TreasureDeposit:Start()
	self._Trove:Add(self.Instance.Touched:Connect(function(hit)
		local player = PlayerUtils.GetPlayerFromPart(hit)
		-- Ensure the player touching it is us, and we are holding a treasure
		if player == Player and Treasure.HoldingTreasure:Get() then
			local treasure = Treasure.HoldingTreasure:Get()

			-- Check if the treasure is already being claimed to prevent spam
			if not treasure._Claimed then
				-- Pass 'self.Instance' so the treasure knows where to animate to
				treasure:Claim(self.Instance)
			end
		end
	end))
end

function TreasureDeposit:Stop()
	self._Trove:Clean()
end

return TreasureDeposit
