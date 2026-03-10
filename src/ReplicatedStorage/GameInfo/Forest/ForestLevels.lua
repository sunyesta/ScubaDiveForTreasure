local ForestDepth = 30

local Types = {
	Ambush = "Ambush", -- Enemies
	Effect = "Effect", -- Buff or debuff
	Treasure = "Treasure", -- predefined treasure
	Custom = "Custom", -- only define the layout
}

local BiomeDepthRanges = {
	LightForest = NumberRange.new(1, 10),
	InnerForest = NumberRange.new(11, ForestDepth),
}

local ScreenEffects = {
	Negative = "Negative",
	Positive = "Positive",
}

local Cards = {

	Slimes = {
		ID = "Slimes",
		Chance = 0.3,
		DepthRange = BiomeDepthRanges.LightForest,
		Action = {
			Type = Types.Ambush,
			Entities = { -- Separated into rounds
				{
					{ Name = "Slime", DifficultyScale = 1 },
					{ Name = "Slime", DifficultyScale = 1 },
					{ Name = "Slime", DifficultyScale = 1 },
				},
				{
					{ Name = "Slime", DifficultyScale = 1 },
					{ Name = "Slime", DifficultyScale = 1 },
					{ Name = "Slime", DifficultyScale = 1 },
				},
			},
		},
	},

	EnergyConsumption = {
		ID = "EnergyConsumption",
		Name = "The Starving Lung",
		Chance = 0.3,
		DepthRange = BiomeDepthRanges.LightForest,
		Action = {
			Type = Types.Effect,
			ScreenEffect = ScreenEffects.Negative,
			Effect = {
				Message = "Every breath feels like ash. You find it harder to travel.",
				Attribute = "EnergyConsumption",
				modifier = 2.0,
				duration = -1, -- number of steps before the effect wears off. -1 = permanent
			},
		},
	},

	SmallTreasure = {
		ID = "SmallTreasure",
		Chance = 0.3,
		DepthRange = BiomeDepthRanges.LightForest,
		Action = {
			Type = Types.Treasures,
			Treasures = {
				"necklace",
				"bracelet",
			},
		},
	},

	RockCliffs = {
		ID = "RockCliffs",
		Chance = 0.3,
		DepthRange = BiomeDepthRanges.LightForest,
		Action = {
			Type = Types.Custom,
			LayoutName = "RockCliffs",
		},
	},
}

local ForestLevels = {
	ForestDepth = ForestDepth,
	Types = Types,
	ScreenEffects = ScreenEffects,
	Cards = Cards,
}

return ForestLevels
