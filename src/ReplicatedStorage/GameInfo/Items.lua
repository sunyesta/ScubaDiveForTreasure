-- Items.lua

local Rarities = {
	Common = 0.9,
	Uncommon = 0.2,
	Rare = 0.03,
}
local MAX_STACK_SIZE = 20

return {
	ItemTemplate = {
		ID = "ItemTemplate",
		Name = "Item",
		Description = "",
		AssetName = "ItemTemplate",
		Icon = "rbxassetid://132764500289277",
		Stackable = true,
		MaxStackSize = MAX_STACK_SIZE,
		Throwable = true,

		ChestRarity = Rarities.Common,
	},

	OxygenCoral = {
		ID = "OxygenCoral",
		Name = "Oxygen Coral",
		Description = "",
		AssetName = "OxygenCoralTool",
		Icon = "rbxassetid://78910014998353",
		Stackable = true,
		MaxStackSize = MAX_STACK_SIZE,
		Throwable = true,
		ChestRarity = Rarities.Common,
	},
}
