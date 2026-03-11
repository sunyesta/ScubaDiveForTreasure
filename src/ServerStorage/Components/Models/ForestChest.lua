local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)
local PlayerComm = PlayerContext.Client.Comm

local ForestChestServer = {}

-- Individual Treasure Tracking: [UserId][ChestID] = true
ForestChestServer.LootedChests = {}

function ForestChestServer.Start()
	-- Initialize table for new players
	Players.PlayerAdded:Connect(function(player)
		ForestChestServer.LootedChests[player.UserId] = {}
	end)

	-- Clean up to prevent memory leaks
	Players.PlayerRemoving:Connect(function(player)
		ForestChestServer.LootedChests[player.UserId] = nil
	end)
end

-- Bound function for the client to request opening a chest
PlayerComm:BindFunction("OpenForestChest", function(player, chestID, treasuresList)
	local userChests = ForestChestServer.LootedChests[player.UserId]

	-- Check if player has already looted this exact chest instance
	if userChests and userChests[chestID] then
		return false, "You have already looted this chest!"
	end

	-- Mark as looted
	if userChests then
		userChests[chestID] = true
	end

	-- Process rewards (In a real game, interface with an InventoryService here)
	-- InventoryService.GiveItems(player, treasuresList)

	return true, "Chest looted successfully!"
end)

return ForestChestServer
