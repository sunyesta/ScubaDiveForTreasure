local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)

local AlignCFrame = {}
AlignCFrame.__index = AlignCFrame

function AlignCFrame.new(parent: BasePart, attachment0: Attachment, attachment1: Attachment)
	assert(parent:IsA("BasePart"), "parent must be a basepart")
	assert(attachment0 == nil or attachment0:IsA("Attachment"), "attachment0 not an attachment")
	assert(attachment1 == nil or attachment1:IsA("Attachment"), "attachment1 not an attachment")

	local self = setmetatable({}, AlignCFrame)

	-- private properties
	self._Trove = Trove.new()
	local alignPosition = self._Trove:Add(Instance.new("AlignPosition"))
	local alignOrientation = self._Trove:Add(Instance.new("AlignOrientation"))

	-- public properties
	self.CFrame = Property.new(parent:GetPivot())
	self.Active = Property.new(true)

	self.AlignPosition = alignPosition
	self.AlignOrientation = alignOrientation

	alignPosition.Responsiveness = math.huge
	alignOrientation.Responsiveness = math.huge
	alignPosition.MaxForce = math.huge
	alignOrientation.MaxTorque = math.huge
	alignPosition.MaxVelocity = math.huge
	alignOrientation.MaxAngularVelocity = math.huge

	-- set attachment0
	if not attachment0 then
		attachment0 = self._Trove:Add(Instance.new("Attachment"))
		attachment0.Parent = parent
		attachment0.WorldCFrame = parent:GetPivot()
	end

	-- set align position params
	alignPosition.Parent = parent
	alignPosition.Attachment0 = attachment0
	if attachment1 then
		alignPosition.Mode = Enum.PositionAlignmentMode.TwoAttachment
		alignPosition.Attachment1 = attachment1
	else
		alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	end

	-- set align orientation params
	alignOrientation.Parent = parent
	alignOrientation.Attachment0 = attachment0
	if attachment1 then
		alignOrientation.Mode = Enum.OrientationAlignmentMode.TwoAttachment
		alignOrientation.Attachment1 = attachment1
	else
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	end

	-- cframe doesn't affect if attachment exists
	if attachment1 then
		self.CFrame.Changed:Connect(function()
			warn("cframe won't be used because attachment 1 is specified")
		end)
	end

	self.CFrame:Observe(function(cframe)
		alignPosition.Position = cframe.Position
		alignOrientation.CFrame = cframe
	end)

	local activeTrove = self._Trove:Extend()
	self.Active:Observe(function(active)
		activeTrove:Clean()
		if active then
			alignPosition.Parent = parent
			alignOrientation.Parent = parent

			activeTrove:Add(RunService.Stepped:Connect(function()
				if attachment0 and attachment1 then
					-- Calculate target CFrame for the parent part
					-- Parent.CFrame * attachment0.CFrame = attachment1.WorldCFrame
					-- Parent.CFrame = attachment1.WorldCFrame * attachment0.CFrame:Inverse()

					-- Apply PivotOffset to get the target pivot location
					local targetCFrame = attachment1.WorldCFrame * attachment0.CFrame:Inverse()
					parent:PivotTo(targetCFrame * parent.PivotOffset)
				end
			end))
		else
			alignPosition.Parent = nil
			alignOrientation.Parent = nil
		end
	end)

	return self
end

function AlignCFrame:Destroy()
	self._Trove:Clean()
end

return AlignCFrame
