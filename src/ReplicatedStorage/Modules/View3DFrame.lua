--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Assuming standard paths based on your provided code
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)

local View3DFrame = {}
View3DFrame.__index = View3DFrame

export type View3DFrame = typeof(setmetatable(
	{} :: {
		_Trove: any,
		Instance: ViewportFrame,
		Camera: Camera,
		SpinSpeed: any,
		_CurrentAngle: number,
		_TargetCenter: Vector3,
		_TargetDistance: number,
	},
	View3DFrame
))

--[[
	Creates a new View3DFrame instance.
	@param parentFrame The GuiObject where the ViewportFrame will be parented.
]]
function View3DFrame.new(parentFrame: GuiObject): View3DFrame
	local self = setmetatable({}, View3DFrame)
	self._Trove = Trove.new()

	-- Setup ViewportFrame
	self.Instance = self._Trove:Add(Instance.new("ViewportFrame"))
	self.Instance.Size = UDim2.fromScale(1, 1) -- Fills the parent frame by default
	self.Instance.BackgroundTransparency = 1
	self.Instance.Parent = parentFrame

	-- Setup Camera
	self.Camera = self._Trove:Add(Instance.new("Camera"))
	self.Instance.CurrentCamera = self.Camera

	-- Custom State
	self.SpinSpeed = Property.new(0)
	self._CurrentAngle = 0
	self._TargetCenter = Vector3.zero
	self._TargetDistance = 10

	-- Bind spinning logic to RunService using Trove to ensure cleanup
	self._Trove:Connect(RunService.RenderStepped, function(dt: number)
		local speed = self.SpinSpeed:Get()
		if speed > 0 or speed < 0 then
			self._CurrentAngle += speed * dt
			self:_UpdateCameraPosition()
		end
	end)

	return self
end

--[[
	Cleans up the ViewportFrame, Camera, and RunService connections.
]]
function View3DFrame:Destroy()
	self._Trove:Destroy()
end

--[[
	Internal method to reposition the camera based on the current angle, distance, and center.
]]
function View3DFrame:_UpdateCameraPosition()
	-- Create an offset CFrame rotated by our current angle
	local offset = CFrame.Angles(0, self._CurrentAngle, 0) * CFrame.new(0, 0, self._TargetDistance)

	-- Position the camera at the target center + offset, looking at the target center
	self.Camera.CFrame = CFrame.new(self._TargetCenter + offset.Position, self._TargetCenter)
end

--[[
	Calculates the bounding box of all BaseParts and frames the camera perfectly.
]]
function View3DFrame:FocusOnBoundingBox()
	-- We use GetDescendants() instead of GetChildren() to safely grab parts
	-- even if they are nested inside a Model.
	local baseparts = TableUtil.Filter(self.Instance:GetDescendants(), function(inst: Instance)
		return inst:IsA("BasePart")
	end)

	if #baseparts == 0 then
		warn("[View3DFrame] No BaseParts found in ViewportFrame to focus on.")
		return
	end

	-- Initialize min and max vectors to extreme opposites
	local minBounds = Vector3.new(math.huge, math.huge, math.huge)
	local maxBounds = Vector3.new(-math.huge, -math.huge, -math.huge)

	-- Calculate the total bounding box spanning across all parts
	for _, part in ipairs(baseparts) do
		local cf = part.CFrame
		local size = part.Size / 2

		-- Calculate all 8 corners of this specific part
		local corners = {
			cf * Vector3.new(size.X, size.Y, size.Z),
			cf * Vector3.new(-size.X, size.Y, size.Z),
			cf * Vector3.new(size.X, -size.Y, size.Z),
			cf * Vector3.new(-size.X, -size.Y, size.Z),
			cf * Vector3.new(size.X, size.Y, -size.Z),
			cf * Vector3.new(-size.X, size.Y, -size.Z),
			cf * Vector3.new(size.X, -size.Y, -size.Z),
			cf * Vector3.new(-size.X, -size.Y, -size.Z),
		}

		-- Expand the global bounding box to fit these corners
		for _, corner in ipairs(corners) do
			minBounds = Vector3.new(
				math.min(minBounds.X, corner.X),
				math.min(minBounds.Y, corner.Y),
				math.min(minBounds.Z, corner.Z)
			)
			maxBounds = Vector3.new(
				math.max(maxBounds.X, corner.X),
				math.max(maxBounds.Y, corner.Y),
				math.max(maxBounds.Z, corner.Z)
			)
		end
	end

	-- Find the geometric center and the total size (extents) of the bounding box
	local center = (minBounds + maxBounds) / 2
	local extents = maxBounds - minBounds

	-- Find the largest dimension of the model to ensure it fits entirely in view
	local maxExtent = math.max(extents.X, extents.Y, extents.Z)

	-- Calculate the required distance using Trigonometry and the Camera's Field of View
	local fov = math.rad(self.Camera.FieldOfView)

	-- We multiply by 1.2 to add a 20% visual padding so the model doesn't touch the screen edges
	local distance = (maxExtent / 2) / math.tan(fov / 2) * 1.2

	-- Update state and force a camera update
	self._TargetCenter = center
	self._TargetDistance = distance
	self._CurrentAngle = 0

	self:_UpdateCameraPosition()
end

return View3DFrame
