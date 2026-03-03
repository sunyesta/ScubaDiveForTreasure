local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)

local InventoryComm = ServerComm.new(ReplicatedStorage.Comm, "InventoryComm")

local Inventory = PlayerContext.Server.Inventory

local InventoryService = {}

-- Put the model in the player's backpack. If inventory full return false.
function InventoryService.GiveItem(item: Model) end

function InventoryService.TakeItem(item: Model, preferredSlot: Number?) end

return InventoryService
