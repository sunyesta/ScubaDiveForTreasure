-- TODO NOT IN USE YET (right now using player session manager)
local Players = game:GetService("Players")
local PlayerEffectService = {}

-- [[ STATUS EFFECTS SYSTEM ]]
-- Effects persist across level transitions because they are stored on the Player object,
-- not the Character. They are wiped upon the Humanoid's death.

function PlayerEffectService.Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")

			humanoid.Died:Connect(function()
				PlayerEffectService.ClearAllEffects(player)
			end)
		end)
	end)

	-- Global function to allow ForestService to apply effects easily
	_G.ApplyStatusEffect = function(player, effectData)
		PlayerEffectService.ApplyEffect(player, effectData)
	end
end

function PlayerEffectService.ApplyEffect(player, effectData)
	-- effectData looks like: { Attribute = "EnergyConsumption", modifier = 2.0 }
	-- We use Player Attributes to store buffs/debuffs so the Client can read them natively
	player:SetAttribute(effectData.Attribute, effectData.modifier)

	-- Optional: Fire a RemoteEvent here to show a UI notification to the player
	-- PlayerComm:GetSignal("ShowEffectNotification"):FireClient(player, effectData.Message)
end

function PlayerEffectService.ClearAllEffects(player)
	-- Remove all attributes related to effects (assuming they are custom ones)
	player:SetAttribute("EnergyConsumption", nil)
	-- Add other effect attribute names here as you expand `Cards`
end

return PlayerEffectService
