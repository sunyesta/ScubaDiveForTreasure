local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService") -- Added RunService
local SoundUtils = require(ReplicatedStorage.NonWallyPackages.SoundUtils)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)

local Player = Players.LocalPlayer

local WaterAmbience = SoundUtils.MakeSound("rbxassetid://391263180", script)
WaterAmbience.Looped = true

local WaterController = {}

WaterController.PlayerInWater = Property.new(false)

function WaterController.GameStart()
	PlayerUtils.ObserveCharacterAdded(Player, function(character, characterTrove)
		-- Wait for the root part to exist so we can track position
		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if not rootPart then
			return
		end

		-- Run a check every physics frame
		characterTrove:Connect(RunService.Heartbeat, function()
			local isBelowWaterLevel = rootPart.Position.Y < 98

			-- Only update if the value is different to avoid spamming signals
			if WaterController.PlayerInWater:Get() ~= isBelowWaterLevel then
				WaterController.PlayerInWater:Set(isBelowWaterLevel)
			end
		end)
	end)
end

return WaterController
