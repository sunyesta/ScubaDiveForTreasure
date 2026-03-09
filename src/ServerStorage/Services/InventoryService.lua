--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)
local Items = require(ReplicatedStorage.Common.GameInfo.Items)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)

local InventoryComm = ServerComm.new(ReplicatedStorage.Comm, "InventoryComm")
local InventoryService = {}

local CONFIG = {
	MaxSlots = 30,
}

-- Put the model in the player's backpack. If inventory full return false.
function InventoryService.GiveItem(player: Player, itemID: string, amount: number): boolean
	local inventoryProp = PlayerContext.Client.Inventory:GetFor(player)
	if not inventoryProp then
		return false
	end

	local currentInventory = TableUtil.Copy(inventoryProp, true)
	local itemInfo = Items[itemID]
	if not itemInfo then
		warn("Invalid item ID:", itemID)
		return false
	end

	amount = amount or 1
	local remainingAmount = amount

	-- 1. Try to fill existing stacks first
	if itemInfo.Stackable then
		for slot = 1, CONFIG.MaxSlots do
			local slotData = currentInventory[slot]
			if slotData and slotData.ID == itemID and slotData.Amount < itemInfo.MaxStackSize then
				local spaceLeft = itemInfo.MaxStackSize - slotData.Amount
				local amountToAdd = math.min(spaceLeft, remainingAmount)

				slotData.Amount += amountToAdd
				remainingAmount -= amountToAdd

				if remainingAmount <= 0 then
					break
				end
			end
		end
	end

	-- 2. Try to put remaining items in empty slots
	if remainingAmount > 0 then
		for slot = 1, CONFIG.MaxSlots do
			if not currentInventory[slot] then
				local amountToAdd = itemInfo.Stackable and math.min(remainingAmount, itemInfo.MaxStackSize) or 1

				currentInventory[slot] = {
					ID = itemID,
					Amount = amountToAdd,
				}

				remainingAmount -= amountToAdd
				if remainingAmount <= 0 then
					break
				end
			end
		end
	end

	-- If we still have remaining amount, the inventory is full
	if remainingAmount > 0 then
		return false
	end

	-- Clone the physical model(s) to the player's backpack
	if itemInfo.AssetName then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for i = 1, amount do
				local model = GetAssetByName(itemInfo.AssetName):Clone()
				model.Parent = backpack
			end
		end
	end

	-- Update the Comm Property which automatically replicates to the client
	PlayerContext.Client.Inventory:SetFor(player, currentInventory)
	return true
end

-- Validates and processes a slot swap or stack combination
function InventoryService.SwapSlots(player: Player, slotNum0: number, slotNum1: number): boolean
	-- [SECURITY]: Validate inputs. Exploiters can send nils, strings, or numbers out of bounds.
	if type(slotNum0) ~= "number" or type(slotNum1) ~= "number" then
		return false
	end
	if slotNum0 < 1 or slotNum0 > CONFIG.MaxSlots or slotNum1 < 1 or slotNum1 > CONFIG.MaxSlots then
		return false
	end
	if math.floor(slotNum0) ~= slotNum0 or math.floor(slotNum1) ~= slotNum1 then
		return false
	end
	if slotNum0 == slotNum1 then
		return true
	end -- Nothing to do

	local currentInventory = TableUtil.Copy(PlayerContext.Client.Inventory:GetFor(player) or {}, true)

	local item0 = currentInventory[slotNum0]
	local item1 = currentInventory[slotNum1]

	-- [SECURITY]: Player tried to move an item from an empty slot (Ghosting attempt)
	if not item0 then
		return false
	end

	-- Stacking Logic
	if item1 and item0.ID == item1.ID and Items[item0.ID].Stackable then
		local maxStack = Items[item0.ID].MaxStackSize
		local totalAmount = item0.Amount + item1.Amount

		if totalAmount <= maxStack then
			-- Completely merges into slot1
			currentInventory[slotNum1].Amount = totalAmount
			currentInventory[slotNum0] = nil
		else
			-- Partially merges, leaves remainder in slot0
			currentInventory[slotNum1].Amount = maxStack
			currentInventory[slotNum0].Amount = totalAmount - maxStack
		end
	else
		-- Normal Swap
		currentInventory[slotNum0] = item1
		currentInventory[slotNum1] = item0
	end

	-- Finalize and replicate
	PlayerContext.Client.Inventory:SetFor(player, currentInventory)
	return true
end

-- Add this to InventoryService.lua!
function InventoryService.ThrowItem(player: Player, slotNum: number): boolean
	local currentInventory = TableUtil.Copy(PlayerContext.Client.Inventory:GetFor(player) or {}, true)
	local itemData = currentInventory[slotNum]

	if not itemData then
		return false
	end

	-- Decrement the server's true stack
	if itemData.Amount and itemData.Amount > 1 then
		itemData.Amount -= 1
	else
		currentInventory[slotNum] = nil
	end

	-- Sync it to the Client
	PlayerContext.Client.Inventory:SetFor(player, currentInventory)
	return true
end

function InventoryService.PopulateBackpack(player)
	local backpack = player.Backpack
	if not backpack then
		return
	end

	local currentInventory = PlayerContext.Client.Inventory:GetFor(player) or {}

	-- Loop through their saved items
	for _, slotData in pairs(currentInventory) do
		local itemInfo = Items[slotData.ID]
		if itemInfo and itemInfo.AssetName then
			-- Clone a physical model for every item in the stack
			for i = 1, slotData.Amount do
				local model = GetAssetByName(itemInfo.AssetName):Clone()
				model.Parent = backpack
			end
		end
	end
end

function InventoryService.GameStart()
	PlayerUtils.ObservePlayerAdded(function(player, playerTrove)
		PlayerContext.Client.PlayerLoaded:WaitForTrueFor(player):andThen(function()
			InventoryService.PopulateBackpack(player)
		end)
	end)
end

-- Be sure to bind it at the bottom of the server script!
InventoryComm:BindFunction("ThrowItem", InventoryService.ThrowItem)

-- Bind the function to Comm so the client can call it
InventoryComm:BindFunction("SwapSlots", InventoryService.SwapSlots)

return InventoryService
