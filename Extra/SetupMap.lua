local Selection = game:GetService("Selection")

-- Get all currently selected objects
local selectedObjects = Selection:Get()

if #selectedObjects == 0 then
	warn("Nothing is selected! Please select a model first.")
else
	local map = selectedObjects[1]

	local WaterBackground: MeshPart = map.WaterBackground
	WaterBackground.Color = Color3.fromRGB(45, 107, 135)
	WaterBackground.Material = Enum.Material.Neon
	WaterBackground.Anchored = true

	local WaterTop: MeshPart = map.WaterTop
	WaterTop.Color = Color3.fromRGB(45, 107, 135)
	WaterTop.Material = Enum.Material.Neon
	WaterTop.CanCollide = false
	WaterTop.DoubleSided = true
	WaterTop.Anchored = true

	local Water: MeshPart = map.Water
	Water.CanCollide = false
	Water.Transparency = 1
	Water.Anchored = true
	Water:AddTag("Water")

	local Dock: MeshPart = map.Dock
	Dock.Color = Color3.fromRGB(105, 64, 40)
	Dock.Anchored = true

	local Ground: MeshPart = map.Ground
	Ground.Color = Color3.fromRGB(163, 162, 165)
	Ground.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	Ground.Anchored = true
end
