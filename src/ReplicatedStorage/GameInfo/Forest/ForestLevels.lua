local MaxDepth = 30

local Types = {

	RandomEncounter = "RandomEncounter",
	Ambush = "Ambush", -- Random amount of a single entity type
	Effect = "Effect", -- Buff or debuff
	Treasure = "Treasure", -- predefined treasure
	RandomTreasure = "RandomTreasure", -- random treasure
	TreasureGambit = "TreasureGambit",
	RandomEffect = "RandomEffect",
	Encounter = "Encounter",
}

local ScreenEffects = {
	Negative = "Negative",
	Positive = "Positive",
}

local Cards = {

	EasyMonsters = {
		ID = "EasyMonsters",
		Weight = 1,
		DepthRange = NumberRange.new(1, MaxDepth),
		Action = {
			Type = Types.Ambush,
			MapVariant = nil, -- optional
			EntityCount = 5,
			PossibleEntities = {
				{ Name = "Slime", DifficultyScale = 1, Weight = 0.1 },
				{ Name = "Goblin", DifficultyScale = 1, Weight = 5 },
			},
		},
	},

	Pain_001 = {
		ID = "Pain_001",
		Name = "The Starving Lung",

		Weight = 1,
		DepthRange = NumberRange.new(1, MaxDepth),
		Action = {
			Type = Types.Effect,
			ScreenEffect = ScreenEffects.Negative,
			Effect = {
				Message = "Every breath feels like ash. You find it harder to travel.",
				MapVariant = nil, -- optional
				Attribute = "EnergyConsumption",
				modifier = 2.0,
				duration = -1, -- number of steps before the effect wears off. -1 = permanent
			},
		},
	},

	SmallTreasure = {
		ID = "SmallTreasure",
		Weight = 1,
		DepthRange = NumberRange.new(1, MaxDepth),
		Action = {
			Type = Types.Treasure,
			MapVariant = nil, -- optional
			TreasureCount = 5,
			PossibleTreasures = {
				{ Name = "10Coins", Chance = 0.7 },
				{ Name = "200Coins", Chance = 0.1 },
				{ Name = "Necklace", Chance = 0.05 },
			},
		},
	},

	TreasureGambit1 = {
		ID = "TreasureGambit1",
		Name = "Treasure Gambit",
		Weight = 1,
		DepthRange = NumberRange.new(1, MaxDepth),
		Action = {
			Type = Types.Treasure,
			MapVariant = nil, -- optional

			Success = {
				TreasureCount = 5,
				PossibleTreasures = {
					{ Name = "10Coins", Chance = 0.7 },
					{ Name = "200Coins", Chance = 0.1 },
					{ Name = "Necklace", Chance = 0.05 },
				},
			},

			Failure = {
				EntityCount = 5,
				PossibleEntities = {
					{ Name = "Slime", DifficultyScale = 1, Weight = 0.1 },
					{ Name = "Goblin", DifficultyScale = 1, Weight = 5 },
				},
			},
		},
	},
}

local ForestLevels = {
	MaxDepth = MaxDepth,
	Types = Types,
	ScreenEffects = ScreenEffects,
	Cards = Cards,
}

return ForestLevels
