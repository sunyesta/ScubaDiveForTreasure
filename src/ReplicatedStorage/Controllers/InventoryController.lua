local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Items = require(ReplicatedStorage.Common.GameInfo.Items)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local InventoryComm = ClientComm.new(ReplicatedStorage.Comm, true, "InventoryComm"):BuildObject()

local Inventory = Property.new({}) --lagless client side inventory

local InventoryController = {}

InventoryController.Config = {
	Slots = 30,
	HotbarSlots = 10,
	NextHotbarKey = Enum.KeyCode.L,
}

function InventoryController.GameStart()
	-- use number key listener to set hotbar index
end

function InventoryController.SwapSlots(slotNum0, slotNum1) end

function InventoryController.ThrowItem(slotNum) end

-- Every item is kept in the player’s backpack and Inventory Controller will be in charge of parenting it to the character when it’s out.
function InventoryController.SetHotbarIndex() end

function InventoryController.NextHotbar() end

function InventoryController.CanTakeItem(model: Model)
	assert(Items[model.Name], "Model is not an item")
	local item = Items[model.Name]
end

return InventoryController
