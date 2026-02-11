local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local CharacterSetupService = {}

function CharacterSetupService.GameStart()
	PlayerUtils.ObservePlayerAdded(function(player, playerTrove)
		playerTrove:Add(PlayerUtils.ObserveCharacterAdded(player, function(character, characterTrove)
			local TemplateRig = GetAssetByName("TemplateRig")

			local OverheadCarryAttachment = TemplateRig.UpperTorso.OverheadCarryAttachment:Clone()
			OverheadCarryAttachment.Parent = character.UpperTorso
			print(
				TemplateRig.UpperTorso.OverheadCarryAttachment,
				TemplateRig.UpperTorso.OverheadCarryAttachment.Position
			)
		end))
	end)
end

return CharacterSetupService
