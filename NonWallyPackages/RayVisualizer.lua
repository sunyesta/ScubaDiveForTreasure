local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure Trove is available. Adjust path if your structure is different.
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local BasePart = Instance.new("Part")
BasePart.Anchored = true
BasePart.Name = "RayVisualizerBasePart"
BasePart.Transparency = 1
BasePart.CanCollide = false
BasePart.CanQuery = false
BasePart.CanTouch = false
BasePart.Parent = workspace

local beamTemplate = Instance.new("Beam")
beamTemplate.Segments = 1
beamTemplate.Width0 = 0.1
beamTemplate.Width1 = 0.1
beamTemplate.FaceCamera = true
beamTemplate.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 165, 165)),
})

local RayVisualizer = {}
RayVisualizer.__index = RayVisualizer

-- Helper function to generate a fading color sequence
local function getColorSequence(color: Color3)
	local h, s, v = color:ToHSV()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 0.1, 1)),
	})
end

--[=[
    Standard Ray Visualizer
    @param origin Vector3 -- Start position
    @param direction Vector3 -- Direction and length
    @param seconds number? -- How long it lasts
    @param color Color3? -- Visual color
]=]
function RayVisualizer.new(origin: Vector3, direction: Vector3, seconds: number?, color: Color3?)
	local self = setmetatable({}, RayVisualizer)
	self.Trove = Trove.new()

	local visualColor = color or Color3.fromRGB(255, 0, 0)

	self.Beam = self.Trove:Add(beamTemplate:Clone())
	self.Attachment0 = self.Trove:Add(Instance.new("Attachment"))
	self.Attachment1 = self.Trove:Add(Instance.new("Attachment"))

	self.Beam.Parent = BasePart
	self.Attachment0.Parent = BasePart
	self.Attachment1.Parent = BasePart

	self.Attachment0.WorldCFrame = CFrame.new(origin)
	self.Attachment1.WorldCFrame = CFrame.new(origin + direction)

	self.Beam.Attachment0 = self.Attachment0
	self.Beam.Attachment1 = self.Attachment1
	self.Beam.Color = getColorSequence(visualColor)

	if seconds then
		task.delay(seconds, function()
			self:Destroy()
		end)
	end

	return self
end

--[=[
    Spherecast Visualizer
    @param origin Vector3 -- Start position
    @param radius number -- Radius of the sphere
    @param direction Vector3 -- Path taken
    @param seconds number?
    @param color Color3?
]=]
function RayVisualizer.sphereCast(origin: Vector3, radius: number, direction: Vector3, seconds: number?, color: Color3?)
	local self = RayVisualizer.new(origin, direction, seconds, color)
	local visualColor = color or Color3.fromRGB(0, 255, 0)

	-- Create a sphere to represent the cast volume
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Color = visualColor
	sphere.Transparency = 0.7
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.Position = origin
	sphere.Parent = BasePart

	self.Trove:Add(sphere)

	-- Optional: Create a second sphere at the end of the cast
	local endSphere = sphere:Clone()
	endSphere.Position = origin + direction
	endSphere.Parent = BasePart
	self.Trove:Add(endSphere)

	return self
end

--[=[
    Blockcast Visualizer (Cube/Box)
    @param cframe CFrame -- Starting CFrame (position and orientation)
    @param size Vector3 -- Size of the box
    @param direction Vector3 -- Path taken
    @param seconds number?
    @param color Color3?
]=]
function RayVisualizer.blockCast(cframe: CFrame, size: Vector3, direction: Vector3, seconds: number?, color: Color3?)
	local self = RayVisualizer.new(cframe.Position, direction, seconds, color)
	local visualColor = color or Color3.fromRGB(0, 0, 255)

	local box = Instance.new("Part")
	box.Size = size
	box.Color = visualColor
	box.Transparency = 0.7
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CFrame = cframe
	box.Parent = BasePart

	self.Trove:Add(box)

	-- End position box
	local endBox = box:Clone()
	endBox.CFrame = cframe + direction
	endBox.Parent = BasePart
	self.Trove:Add(endBox)

	return self
end

--[=[
    Quick helper for RaycastResults
]=]
function RayVisualizer.newFromRaycast(
	origin: Vector3,
	direction: Vector3,
	result: RaycastResult?,
	seconds: number?,
	color: Color3?
)
	local finalDirection = if result then direction.Unit * result.Distance else direction
	return RayVisualizer.new(origin, finalDirection, seconds, color)
end

function RayVisualizer:Destroy()
	if self.Trove then
		self.Trove:Clean()
		self.Trove = nil
	end
end

return RayVisualizer
