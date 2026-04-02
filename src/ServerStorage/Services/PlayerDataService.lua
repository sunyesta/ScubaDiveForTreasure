--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Adjust this path if your ProfileStore location differs
local ProfileStore = require(ReplicatedStorage.NonWallyPackages.ProfileStore)
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)
local Trove = require(ReplicatedStorage.Packages.Trove)

local PlayerDataService = {}
PlayerDataService.Profiles = {}

-- 1. Added Inventory to the default Profile Template
local PROFILE_TEMPLATE = {
	Wins = 0,
	Inventory = {},
}

local GameProfileStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)

function PlayerDataService.LoadProfile(player: Player)
	local profile = GameProfileStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		-- Assign the profile to the table FIRST, so it exists for GetProfile
		PlayerDataService.Profiles[player] = profile

		-- Pass the profile explicitly to the bind function
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

function PlayerDataService.GetProfile(player: Player)
	return PlayerDataService.Profiles[player]
end

function PlayerDataService.EndSession(player: Player)
	local profile = PlayerDataService.Profiles[player]
	if profile then
		profile:EndSession()
		PlayerDataService.Profiles[player] = nil
	end
end

function PlayerDataService._BindPlayerContextToProfile(player: Player, profile: any)
	local trove = Trove.new()

	-- 2 & 3. Bind Inventory (Load initial data, then observe for changes)
	-- PlayerContext.Client.Inventory:SetFor(player, profile.Data.Inventory)
	-- trove:Add(PlayerContext.Client.Inventory:ObserveFor(player, function(inventory)
	-- 	-- Whenever InventoryService calls :SetFor(), this observer fires
	-- 	-- and updates the Profile data ready for the next auto-save.
	-- 	profile.Data.Inventory = inventory
	-- end))

	return trove
end

return PlayerDataService
