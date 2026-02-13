local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local PlayerDataService = require(ServerStorage.Source.Services.PlayerDataService)
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)
local ModelUtils = require(ReplicatedStorage.NonWallyPackages.ModelUtils)

Players.CharacterAutoLoads = false

local PlayerStartService = {}

function PlayerStartService.GameStart()
	PlayerUtils.ObservePlayerAdded(function(player, playerTrove)
		-- 1. Load Profile
		local profile = PlayerDataService.LoadProfile(player)

		if not profile then
			return -- Kick is handled within PlayerDataService
		end

		-- End the player's session once they leave
		playerTrove:Add(function()
			PlayerDataService.EndSession(player)
		end)

		-- manually load character
		playerTrove:Add(PlayerUtils.ObserveCharacterAdded(player, function(character, characterTrove)
			local humanoid = character:WaitForChild("Humanoid")

			ModelUtils.ApplyToAllBaseParts(character, function(part)
				part.CollisionGroup = "Characters"
			end)

			humanoid.Died:Once(function()
				if player and player.Parent then
					player:LoadCharacter()
				end
			end)
		end))

		-- 3. Initial Spawn
		player:LoadCharacter()
		PlayerContext.Client.PlayerLoaded:SetFor(player, true)
	end)
end

return PlayerStartService
