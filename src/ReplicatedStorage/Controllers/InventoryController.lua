--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Assume these paths are correct based on your environment
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Items = require(ReplicatedStorage.Common.GameInfo.Items)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Input = require(ReplicatedStorage.Packages.Input)

local InventoryComm = ClientComm.new(ReplicatedStorage.Comm, true, "InventoryComm")
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm")

local InventoryServer = InventoryComm:BuildObject()
local Keyboard = Input.Keyboard.new()

local InventoryController = {}

InventoryController.Config = {
	Slots = 30,
	HotbarSlots = 10,
	NextHotbarKey = Enum.KeyCode.L,
}

InventoryController.ActiveHotbarSlot = Property.new(nil :: number?)
InventoryController.Inventory = Property.new({})
InventoryController._equippedItemConnection = nil :: RBXScriptConnection?

local TrueInventoryProp

local KeycodeToSlot = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

function InventoryController.GameStart()
	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local clientPlayerComm = PlayerComm:BuildObject()
	TrueInventoryProp = clientPlayerComm.Inventory

	TrueInventoryProp:Observe(function(serverInventory)
		InventoryController.Inventory:Set(TableUtil.Copy(serverInventory, true))
	end)

	-- BUG FIX: Listen to our own local inventory state. If it changes, check if the active slot needs an update.
	InventoryController.Inventory:Observe(function(newInventory)
		local activeSlot = InventoryController.ActiveHotbarSlot:Get()
		if activeSlot then
			-- We use defer so that we process this after all state changes for this frame have finished
			task.defer(function()
				InventoryController._refreshEquippedItem(activeSlot)
			end)
		end
	end)

	Keyboard.KeyUp:Connect(function(keycode)
		local targetSlot = KeycodeToSlot[keycode]
		if targetSlot and targetSlot <= InventoryController.Config.HotbarSlots then
			InventoryController.SetHotbarIndex(targetSlot)
		end
	end)
end

function InventoryController.SwapSlots(slotNum0: number, slotNum1: number)
	if slotNum0 == slotNum1 then
		return
	end

	local currentInv = TableUtil.Copy(InventoryController.Inventory:Get(), true)
	local item0 = currentInv[slotNum0]
	local item1 = currentInv[slotNum1]

	if not item0 and not item1 then
		return
	end

	-- Optimistic UI Update
	if item1 and item0 and item0.ID == item1.ID and Items[item0.ID].Stackable then
		local maxStack = Items[item0.ID].MaxStackSize
		local total = item0.Amount + item1.Amount
		if total <= maxStack then
			currentInv[slotNum1].Amount = total
			currentInv[slotNum0] = nil
		else
			currentInv[slotNum1].Amount = maxStack
			currentInv[slotNum0].Amount = total - maxStack
		end
	else
		currentInv[slotNum0] = item1
		currentInv[slotNum1] = item0
	end

	InventoryController.Inventory:Set(currentInv)

	-- Verification
	InventoryServer:SwapSlots(slotNum0, slotNum1):andThen(function(success: boolean)
		if not success then
			InventoryController.Inventory:Set(TableUtil.Copy(TrueInventoryProp:Get(), true))
		end
	end)
end

function InventoryController.ThrowItem(slotNum: number)
	local currentInv = TableUtil.Copy(InventoryController.Inventory:Get(), true)
	local item = currentInv[slotNum]
	if not item then
		return
	end

	if item.Amount and item.Amount > 1 then
		currentInv[slotNum].Amount -= 1
	else
		currentInv[slotNum] = nil
	end

	InventoryController.Inventory:Set(currentInv)

	InventoryServer:ThrowItem(slotNum)
		:andThen(function(success: boolean)
			if not success then
				warn("Server rejected item throw. Rolling back.")
				InventoryController.Inventory:Set(TableUtil.Copy(TrueInventoryProp:Get(), true))
			end
		end)
		:catch(function(err)
			warn("Network error during item throw. Rolling back.", err)
			InventoryController.Inventory:Set(TableUtil.Copy(TrueInventoryProp:Get(), true))
		end)
end

-- Internal helper to refresh physical items without changing selection state
function InventoryController._refreshEquippedItem(index: number)
	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChild("Backpack")

	if not character or not humanoid or not backpack then
		return
	end

	local currentInv = InventoryController.Inventory:Get()
	local slotData = currentInv[index]
	local itemInfo = slotData and Items[slotData.ID]

	-- BUG FIX: Check if the correct item is ALREADY equipped!
	-- This prevents the animation from stuttering or resetting when picking up stackable items.
	if itemInfo and itemInfo.AssetName then
		local currentlyEquipped = character:FindFirstChild(itemInfo.AssetName)
		if currentlyEquipped then
			return -- Item is already perfectly in hand, no action needed!
		end
	end

	-- Cleanup previous
	if InventoryController._equippedItemConnection then
		InventoryController._equippedItemConnection:Disconnect()
		InventoryController._equippedItemConnection = nil
	end

	humanoid:UnequipTools()

	if slotData and itemInfo and itemInfo.AssetName then
		-- BUG FIX: Use WaitForChild with a short timeout.
		-- When the server grants a new item, the network data updates instantly, but the Tool Instance
		-- might take a few frames to arrive in the Backpack.
		local asset = backpack:FindFirstChild(itemInfo.AssetName)
		if not asset then
			asset = backpack:WaitForChild(itemInfo.AssetName, 1) -- Wait up to 1 second for replication
		end

		-- Make sure the player didn't change slots while we yielded for WaitForChild!
		if InventoryController.ActiveHotbarSlot:Get() ~= index then
			return
		end

		if asset then
			if asset:IsA("Tool") then
				humanoid:EquipTool(asset)
			else
				asset.Parent = character
			end

			InventoryController._equippedItemConnection = asset.AncestryChanged:Connect(function(_, newParent)
				if newParent == character or newParent == backpack then
					return
				end

				if InventoryController._equippedItemConnection then
					InventoryController._equippedItemConnection:Disconnect()
					InventoryController._equippedItemConnection = nil
				end

				task.defer(function()
					if InventoryController.ActiveHotbarSlot:Get() == index then
						InventoryController.ThrowItem(index)
						InventoryController._refreshEquippedItem(index)
					end
				end)
			end)
		end
	end
end

-- Public method for input-based slot changes
function InventoryController.SetHotbarIndex(index: number)
	local activeSlot = InventoryController.ActiveHotbarSlot:Get()

	-- Toggle Off if selecting the same active slot
	if activeSlot == index then
		InventoryController.ActiveHotbarSlot:Set(nil)
		InventoryController._refreshEquippedItem(0) -- Index 0 clears everything
		return
	end

	-- Set new state and equip
	InventoryController.ActiveHotbarSlot:Set(index)
	InventoryController._refreshEquippedItem(index)
end

return InventoryController
