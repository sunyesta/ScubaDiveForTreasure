local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local CharacterSetupService = {}

function CharacterSetupService.GameStart()
	PlayerUtils.ObservePlayerAdded(function(player, playerTrove)
		playerTrove:Add(PlayerUtils.ObserveCharacterAdded(player, function(character, characterTrove)
			local TemplateRig = GetAssetByName("TemplateRig")

			local TemplateChestCarryAttachment = TemplateRig:FindFirstChild("ChestCarryAttachment", true)

			local ChestCarryAttachment = TemplateChestCarryAttachment:Clone()
			ChestCarryAttachment.Parent = character[TemplateChestCarryAttachment.Parent.Name]
			print("temp", TemplateChestCarryAttachment.Position, ChestCarryAttachment.Position)
		end))
	end)
end

return CharacterSetupService
