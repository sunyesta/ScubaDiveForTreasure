local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)

--!strict
local RangeVisualizer = {}
RangeVisualizer.__index = RangeVisualizer

-- Create a template part once for optimization
local TemplateCylinder = Instance.new("Part")
TemplateCylinder.Name = "RangeVisualizer"
TemplateCylinder.Shape = Enum.PartType.Cylinder
TemplateCylinder.Material = Enum.Material.Neon
TemplateCylinder.Transparency = 0.7
TemplateCylinder.Color = Color3.fromRGB(0, 170, 255) -- A nice light blue
TemplateCylinder.CastShadow = false

-- Physics optimizations (Critical for visual-only parts!)
TemplateCylinder.CanCollide = false
TemplateCylinder.CanQuery = false
TemplateCylinder.CanTouch = false
TemplateCylinder.Massless = true
TemplateCylinder.Anchored = false -- Must be unanchored to weld to moving parts

--[[
    Creates a new range cylinder, sizes it, and welds it to the given part.
    
    @param weldTo: The BasePart you want the range to follow.
    @param range: The radius of the visualizer in studs.
    @param color: The Color3 to apply to the visualizer.
    @return: The RangeVisualizer object instance.
]]
function RangeVisualizer.newConnected(weldTo: BasePart, range: number, color: Color3)
	local self = setmetatable({}, RangeVisualizer)
	self._Trove = Trove.new()

	-- 1. Clone our optimized template and store a reference in `self`
	local visualizer = self._Trove:Add(TemplateCylinder:Clone())
	visualizer.Color = color
	self.VisualizerPart = visualizer -- We save this here so :Toggle() can access it later!

	self.Range = Property.new(range)

	-- 2. Size the cylinder
	-- Cylinders stretch along the X axis. We make X very small (the thickness)
	-- and Y/Z the diameter (range * 2) to form our flat circle.
	local thickness = 0.2
	self.Range:Observe(function()
		local diameter = self.Range:Get() * 2
		visualizer.Size = Vector3.new(thickness, diameter, diameter)
	end)

	-- 3. Position and Rotate
	-- We move it to the target part, then rotate it 90 degrees on the Z-axis
	-- so the flat side of the cylinder faces upwards.
	visualizer.CFrame = weldTo.CFrame * CFrame.Angles(0, 0, math.rad(90))

	-- 4. Weld it together
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = weldTo
	weld.Part1 = visualizer
	weld.Parent = visualizer -- Parent last!

	-- 5. Parent to workspace (Parenting last is best practice for performance)
	visualizer.Parent = workspace

	return self
end

--[[
    Toggles the visibility of the range visualizer.
    
    @param isEnabled: boolean - True to show, false to hide.
]]
function RangeVisualizer:Toggle(isEnabled: boolean)
	-- Safety check to ensure the part still exists
	if not self.VisualizerPart then
		return
	end

	if isEnabled then
		-- Put the part back into the game world to render it
		self.VisualizerPart.Parent = workspace
	else
		-- Parent to nil to hide it efficiently.
		-- The Trove and WeldConstraint will keep it safe until we need it again!
		self.VisualizerPart.Parent = nil
	end
end

--[[
    Completely cleans up the visualizer, disconnecting properties and destroying parts.
]]
function RangeVisualizer:Destroy()
	self._Trove:Destroy()
	self.VisualizerPart = nil
end

return RangeVisualizer
