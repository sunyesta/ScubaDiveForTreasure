local MathUtils = require(script.Parent.Parent.Utils.MathUtils)
local Constants = require(script.Parent.Parent.Utils.Constants)
local CameraState = require(script.Parent.CameraState)

-------------------------------------------------------------------------------
-- VIRTUAL CAMERA
-------------------------------------------------------------------------------
local VirtualCamera = {}
VirtualCamera.__index = VirtualCamera

function VirtualCamera.new(name)
	local self = setmetatable({}, VirtualCamera)
	self.Name = name or "VirtualCamera"
	self.Priority = 0
	self.Follow = nil -- Instance
	self.LookAt = nil -- Instance
	self.Lens = { FieldOfView = Constants.DEFAULT_FOV }

	-- Pipeline components
	self.Body = nil -- Moves Position
	self.Aim = nil -- Rotates Rotation

	-- Internal State
	self.State = CameraState.new()
	return self
end

function VirtualCamera:Update(dt)
	-- Reset state raw position to follow target or current position
	-- Pipeline Stages:

	-- 1. Body (Position)
	if self.Body then
		self.Body:Mutate(self, self.State, dt)
	elseif self.Follow then
		-- Default hard lock if no body
		self.State.Position = MathUtils.GetTargetPosition(self.Follow) or self.State.Position
	end

	-- 2. Aim (Rotation)
	if self.Aim then
		self.Aim:Mutate(self, self.State, dt)
	elseif self.LookAt then
		-- Default hard look
		local target = MathUtils.GetTargetPosition(self.LookAt)
		if target then
			self.State.Rotation = CFrame.lookAt(Vector3.zero, (target - self.State.Position).Unit)
		end
	end

	self.State.FieldOfView = self.Lens.FieldOfView
end

function VirtualCamera:Destroy()
	if self.Body and self.Body.Destroy then
		self.Body:Destroy()
	end
	if self.Aim and self.Aim.Destroy then
		self.Aim:Destroy()
	end
end

return VirtualCamera
