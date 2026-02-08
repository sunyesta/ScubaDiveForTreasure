local CameraState = require(script.Parent.CameraState)
-------------------------------------------------------------------------------
-- CINEMACHINE BRAIN (The Manager)
-------------------------------------------------------------------------------
local Brain = {}
Brain.__index = Brain

function Brain.new()
	local self = setmetatable({}, Brain)
	self.ActiveVirtualCamera = nil
	self.VirtualCameras = {}
	self.DefaultBlendTime = 0.5

	-- Blending Internals
	self.IsBlending = false
	self.BlendTimer = 0
	self.BlendDuration = 0
	self.OutgoingCamera = nil
	self.OutgoingState = CameraState.new()

	self.OutputCamera = workspace.CurrentCamera

	return self
end

function Brain:Register(vcam)
	table.insert(self.VirtualCameras, vcam)
	self:RefreshPriority()
end

function Brain:Unregister(vcam)
	for i, v in ipairs(self.VirtualCameras) do
		if v == vcam then
			table.remove(self.VirtualCameras, i)
			break
		end
	end
	self:RefreshPriority()
end

function Brain:RefreshPriority()
	local highestPrio = -math.huge
	local topCam = nil

	for _, vcam in ipairs(self.VirtualCameras) do
		if vcam.Priority > highestPrio then
			highestPrio = vcam.Priority
			topCam = vcam
		end
	end

	if topCam ~= self.ActiveVirtualCamera then
		self:CutTo(topCam)
	end
end

function Brain:CutTo(newCam)
	if self.ActiveVirtualCamera == newCam then
		return
	end

	-- Capture current state as outgoing if we are switching
	if self.ActiveVirtualCamera then
		-- Snapshot state safely (Copy values)
		self.OutgoingState.Position = self.ActiveVirtualCamera.State.Position
		self.OutgoingState.Rotation = self.ActiveVirtualCamera.State.Rotation
		self.OutgoingState.FieldOfView = self.ActiveVirtualCamera.State.FieldOfView

		self.OutgoingCamera = self.ActiveVirtualCamera
		self.IsBlending = true
		self.BlendDuration = self.DefaultBlendTime
		self.BlendTimer = 0
	else
		-- First camera activation, instant cut
		self.IsBlending = false
	end

	self.ActiveVirtualCamera = newCam
end

function Brain:Update(dt)
	-- Update active camera logic
	if self.ActiveVirtualCamera then
		self.ActiveVirtualCamera:Update(dt)
	end

	-- Update outgoing camera logic if still blending
	if self.IsBlending and self.OutgoingCamera then
		self.OutgoingCamera:Update(dt)
	end

	-- Apply to real camera
	local finalState = CameraState.new()

	if self.ActiveVirtualCamera then
		local activeState = self.ActiveVirtualCamera.State

		if self.IsBlending then
			self.BlendTimer = self.BlendTimer + dt
			local t = math.clamp(self.BlendTimer / self.BlendDuration, 0, 1)

			-- Simple EaseInOut curve
			local smoothT = t * t * (3 - 2 * t)

			-- We blend between the stored outgoing snapshot (or live outgoing) and current active
			-- To make it smoother, update OutgoingState if outgoing camera exists
			if self.OutgoingCamera then
				-- FIX: Copy values instead of overwriting the table reference
				-- This prevents OutgoingState from becoming a reference to a specific camera's state
				self.OutgoingState.Position = self.OutgoingCamera.State.Position
				self.OutgoingState.Rotation = self.OutgoingCamera.State.Rotation
				self.OutgoingState.FieldOfView = self.OutgoingCamera.State.FieldOfView
			end

			finalState = CameraState.Lerp(self.OutgoingState, activeState, smoothT)

			if t >= 1 then
				self.IsBlending = false
				self.OutgoingCamera = nil
			end
		else
			finalState = activeState
		end

		-- Apply to Roblox Camera
		self.OutputCamera.CFrame = CFrame.new(finalState.Position) * finalState.Rotation
		self.OutputCamera.FieldOfView = finalState.FieldOfView
	end
end

return Brain
