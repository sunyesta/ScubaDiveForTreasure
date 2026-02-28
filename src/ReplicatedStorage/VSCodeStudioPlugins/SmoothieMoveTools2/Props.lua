-- Props.lua
local Property = require(script.Parent.Modules.PropertyLite)
local Enums = require(script.Parent.Enums)

-- useage prop:Get(), prop:Set(), prop:Observe()

return {
	Tool = Property.new(Enums.Tools.Select),
	Axis = Property.new(Enums.Axis.Global),
	Origin = Property.new(Enums.Origin.Pivot),
	UseSnapping = Property.new(false),
	SnappingMode = Property.new(Enums.SnappingMode.Grid),
	MatchRotationToSurface = Property.new(false),
	GridSize = Property.new(3),
	ActiveColor = Property.new(Color3.new()),
	SelectedObjects = Property.new({}),
	SelectedParts = Property.new({}),
	ActivePart = Property.new(nil),
	TransformOrigin = Property.new(CFrame.new()),
	SwapYandZKeybinds = Property.new(true),
	MoveStudsIncrement = Property.new(0),
	RotationDegIncrement = Property.new(0),
}
