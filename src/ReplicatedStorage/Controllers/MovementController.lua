local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local Player = Players.LocalPlayer

-- Settings
local WALK_SPEED = 16
local SPRINT_SPEED = 28

local MovementController = {}

function MovementController.GameStart()
	PlayerUtils.ObserveCharacterAdded(Player, function(character, characterTrove)
		local humanoid = character:WaitForChild("Humanoid")

		-- Function to update speed
		local function setSprinting(active)
			humanoid.WalkSpeed = active and SPRINT_SPEED or WALK_SPEED
		end

		-- Listen for Shift key down
		local inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				setSprinting(true)
			end
		end)

		-- Listen for Shift key up
		local inputEnded = UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				setSprinting(false)
			end
		end)

		-- Add connections to the characterTrove for automatic cleanup on death/respawn
		characterTrove:Add(inputBegan)
		characterTrove:Add(inputEnded)

		-- Reset speed if the humanoid somehow changes while alive
		characterTrove:Add(function()
			setSprinting(false)
		end)
	end)
end

return MovementController
