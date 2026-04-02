-- CakeDecoratorTabs.lua
return {
	Color = {
		Type = "Color",
	},
	Bases = {
		Type = "Asset",

		-- Asset Properties
		Title = "Bases",
		Assets = {
			"SingleLayerCylinderBase",
			"DoubleLayerCylinderBase",
			"TripleLayerCylinderBase",
		},
	},
	Paint = {
		Type = "Paint",
	},
	Sprinkles = {
		Type = "Sprinkles",
	},
	Frosting = {
		Type = "Asset",

		-- Asset Properties
		Title = "Frostings",
		Assets = {
			"SphereFrosting",
			"SwirlFrosting",
		},
	},
	Decoration = {
		Type = "Asset",

		-- Asset Properties
		Title = "Decorations",
		Assets = {
			"Cherry",
			"RainbowFruit",
		},
	},
}
