local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Adjust this path if your ProfileStore location differs
local ProfileStore = require(ReplicatedStorage.NonWallyPackages.ProfileStore)
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)
local Trove = require(ReplicatedStorage.Packages.Trove)

local PlayerDataService = {}
PlayerDataService.Profiles = {}

local PROFILE_TEMPLATE = {
	Wins = 0,
}

local GameProfileStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)

function PlayerDataService.LoadProfile(player)
	local profile = GameProfileStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		-- 1. Assign the profile to the table FIRST, so it exists for GetProfile
		PlayerDataService.Profiles[player] = profile

		-- 2. Pass the profile explicitly to the bind function
		local sessionTrove = PlayerDataService._BindPlayerContextToProfile(player, profile)

		profile.OnSessionEnd:Connect(function()
			sessionTrove:Clean()
			PlayerDataService.Profiles[player] = nil
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			print(`[PlayerDataService] Profile loaded for {player.Name}`)
			return profile
		else
			profile:EndSession()
		end
	else
		player:Kick("Profile load fail - Please rejoin")
	end

	return nil
end

function PlayerDataService.GetProfile(player)
	return PlayerDataService.Profiles[player]
end

function PlayerDataService.EndSession(player)
	local profile = PlayerDataService.Profiles[player]
	if profile then
		profile:EndSession()
		PlayerDataService.Profiles[player] = nil
	end
end

-- Added 'profile' as an argument here
function PlayerDataService._BindPlayerContextToProfile(player, profile)
	local trove = Trove.new()

	PlayerContext.Client.Wins:SetFor(player, profile.Data.Wins)
	trove:Add(PlayerContext.Client.Wins:ObserveFor(player, function(wins)
		profile.Data.Wins = wins
	end))

	return trove
end

return PlayerDataService
