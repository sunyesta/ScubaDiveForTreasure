local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

local BasePart = Instance.new("Part")
BasePart.Anchored = true
BasePart.Name = "RayVisualizerBastPart"
BasePart.Transparency = 1
BasePart.CanCollide = false
BasePart.CanQuery = false
BasePart.CanTouch = false
BasePart.Parent = workspace

local beamTemplate = Instance.new("Beam")
beamTemplate.Segments = 1
beamTemplate.Width0 = 0.3
beamTemplate.Width1 = 0.3
beamTemplate.FaceCamera = true
beamTemplate.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 165, 165)),
})

local RayVisualizer = {}
RayVisualizer.__index = RayVisualizer

function RayVisualizer.new(origin, direction, seconds, color: Color3)
	local self = setmetatable({}, RayVisualizer)
	self.Trove = Trove.new()

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

	if color then
		local h, s, v = color:ToHSV()
		self.Beam.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 0.1, 1)),
		})
	end

	if seconds then
		coroutine.wrap(function()
			task.wait(seconds)
			self:Destroy()
		end)()
	end

	return self
end

function RayVisualizer.newFromRaycast(origin, direction, result, seconds)
	if result then
		RayVisualizer.new(origin, direction.Unit * result.Distance, seconds)
	else
		RayVisualizer.new(origin, direction, seconds)
	end
end

function RayVisualizer:Destroy()
	self.Trove:Clean()
end

return RayVisualizer
