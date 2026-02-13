--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Imports
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)
local GameEnums = require(ReplicatedStorage.Common.GameInfo.GameEnums)

-- Type Definitions
type FishConfig = {
	SWIM_RADIUS: number,
	SWIM_SPEED: number,
	LOOK_AHEAD: number,
	WALL_BUFFER: number,
	BANK_FACTOR: number, -- How much the fish leans into turns
	LERP_SPEED: number, -- Visual smoothing factor
	CULL_DISTANCE: number, -- Max distance to render movement
	FISH_SIZE: number, -- Approximate size of the fish model
	VISIBILITY_PADDING: number, -- Extra buffer for culling
}

local CONFIG: FishConfig = {
	SWIM_RADIUS = 15,
	SWIM_SPEED = 0.4,
	LOOK_AHEAD = 0.5,
	WALL_BUFFER = 1.5,
	BANK_FACTOR = 25,
	LERP_SPEED = 10,
	CULL_DISTANCE = 150,
	FISH_SIZE = 4,
	VISIBILITY_PADDING = 10,
}

local FishClient = Component.new({
	Tag = "Fish",
	Ancestors = { Workspace },
})

function FishClient:Construct()
	self._Trove = Trove.new()

	-- State
	self.MovementPlaneOrigin = World2DUtils.DefaultPlaneOrigin
	self.MovementPlaneNormal = World2DUtils.DefaultPlaneNormal
	self.StartPosition = Vector3.zero -- Assigned on Load
	self.CurrentRoll = 0 -- For smooth banking transitions
	self.WasVisible = false -- Track visibility to handle snapping

	-- Attributes
	self.RandomSeed = self.Instance:GetAttribute("RandomSeed") or math.random(1, 10000)

	-- Physics Setup
	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RayParams.FilterDescendantsInstances = { self.Instance }
	self.RayParams.IgnoreWater = true
	self.RayParams.CollisionGroup = GameEnums.CollisionGroups.NoCharacters
end

function FishClient:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))
	partStreamable:Observe(function(rootPart)
		if rootPart then
			self:OnRootPartLoaded(rootPart)
		end
	end)
end

function FishClient:Stop()
	self._Trove:Clean()
end

-- Optimized Visibility Check
-- Complexity: O(1) - Checks if the swim area sphere intersects the frustum
function FishClient:ShouldRender(): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end

	local origin = self.StartPosition
	-- Define the bounding sphere that encompasses the fish's entire possible movement + size + padding
	local checkRadius = CONFIG.SWIM_RADIUS + CONFIG.FISH_SIZE + CONFIG.VISIBILITY_PADDING

	local distToCamera = (camera.CFrame.Position - origin).Magnitude

	-- 1. Coarse Distance Cull (Cheap)
	-- If the closest point of the bounding sphere is beyond the cull distance
	if distToCamera - checkRadius > CONFIG.CULL_DISTANCE then
		return false
	end

	-- 2. Camera Inside Check
	-- If the camera is inside the visibility sphere, always render
	if distToCamera < checkRadius then
		return true
	end

	-- 3. Frustum Cull with Radius (Sphere-Frustum Intersection approximation)
	local screenPoint, onScreen = camera:WorldToViewportPoint(origin)

	if onScreen then
		return true
	end

	-- If the center is off-screen, check if the sphere radius bleeds into the view
	if screenPoint.Z > 0 then
		local viewportSize = camera.ViewportSize

		-- Calculate pixels per stud at the depth of the object
		-- Formula: Height = 2 * Depth * tan(FOV/2)
		local fovRad = math.rad(camera.FieldOfView)
		local frustumHeight = 2 * screenPoint.Z * math.tan(fovRad * 0.5)
		local pxPerStud = viewportSize.Y / frustumHeight

		-- Project the 3D radius to 2D pixel radius
		local radiusPx = checkRadius * pxPerStud

		-- Check bounds with the projected radius expansion
		local minX, maxX = -radiusPx, viewportSize.X + radiusPx
		local minY, maxY = -radiusPx, viewportSize.Y + radiusPx

		return screenPoint.X >= minX and screenPoint.X <= maxX and screenPoint.Y >= minY and screenPoint.Y <= maxY
	end

	return false
end

function FishClient:OnRootPartLoaded(rootPart: BasePart)
	rootPart.Anchored = true
	rootPart.CanCollide = false
	self.StartPosition = rootPart.Position

	-- Calculate Plane Vectors (Orthonormal Basis)
	local normal = self.MovementPlaneNormal.Unit
	local globalUp = Vector3.yAxis

	-- Handle edge case where normal is exactly up/down
	if math.abs(normal:Dot(globalUp)) > 0.99 then
		globalUp = Vector3.xAxis
	end

	self.PlaneRight = normal:Cross(globalUp).Unit
	self.PlaneUp = self.PlaneRight:Cross(normal).Unit

	self._Trove:Connect(RunService.Heartbeat, function(dt: number)
		local isVisible = self:ShouldRender()

		if isVisible then
			-- If we weren't visible last frame, snap to position (no lerp)
			-- This prevents the fish from "flying" in from its old position
			local snap = not self.WasVisible
			self:UpdateMovement(dt, snap)
		end

		self.WasVisible = isVisible
	end)
end

function FishClient:UpdateMovement(dt: number, snap: boolean?)
	-- Sync time with server for deterministic movement across clients
	local t = Workspace:GetServerTimeNow() % 100000
	local seedOffset = self.RandomSeed % 10000

	-- 1. Calculate Target Position (The "Ideal" spot)
	local targetPos = self:GetNoisePosition(t, seedOffset)
	local futurePos = self:GetNoisePosition(t + CONFIG.LOOK_AHEAD, seedOffset)

	-- 2. Wall Avoidance (Slide along wall)
	local toTarget = targetPos - self.Instance:GetPivot().Position

	-- Only check walls if we aren't snapping (prevent raycasting from old position during snap)
	if not snap and toTarget.Magnitude > 0.001 then
		local rayResult = Workspace:Raycast(self.Instance:GetPivot().Position, toTarget, self.RayParams)
		if rayResult then
			-- Project vector onto the wall plane to slide instead of sticking
			local surfaceNormal = rayResult.Normal
			local slideVector = toTarget - (surfaceNormal * toTarget:Dot(surfaceNormal))
			targetPos = rayResult.Position + slideVector + (surfaceNormal * CONFIG.WALL_BUFFER)
		end
	end

	-- 3. Calculate Rotation with Banking
	local lookVector = (futurePos - targetPos).Unit

	-- Avoid NaN if fish isn't moving
	if lookVector.Magnitude < 0.001 then
		lookVector = self.Instance:GetPivot().LookVector
	end

	local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookVector)

	-- Calculate turn sharpness for banking
	local currentCFrame = self.Instance:GetPivot()
	local objectSpaceTurn = currentCFrame:VectorToObjectSpace(lookVector)

	local targetRoll = -objectSpaceTurn.X * CONFIG.BANK_FACTOR

	-- 4. Apply Position and Rotation
	if snap then
		-- Instant Teleport
		self.CurrentRoll = targetRoll -- Reset roll smoothing
		targetCFrame = targetCFrame * CFrame.Angles(0, 0, math.rad(self.CurrentRoll))
		self.Instance:PivotTo(targetCFrame)
	else
		-- Smooth Movement
		-- Smoothly interpolate the roll
		self.CurrentRoll = math.abs(self.CurrentRoll - targetRoll) > 0.01
				and self.CurrentRoll + (targetRoll - self.CurrentRoll) * math.min(dt * 5, 1)
			or targetRoll

		targetCFrame = targetCFrame * CFrame.Angles(0, 0, math.rad(self.CurrentRoll))

		-- PivotTo allows us to move Models without breaking internal welds
		local smoothCFrame = currentCFrame:Lerp(targetCFrame, math.min(dt * CONFIG.LERP_SPEED, 1))
		self.Instance:PivotTo(smoothCFrame)
	end
end

function FishClient:GetNoisePosition(t: number, seed: number): Vector3
	local noiseX = math.noise(t * CONFIG.SWIM_SPEED, seed, 0)
	local noiseY = math.noise(seed, t * CONFIG.SWIM_SPEED, 1)

	-- Multiply by 2 because noise is roughly -0.5 to 0.5
	local offsetX = noiseX * (CONFIG.SWIM_RADIUS * 2)
	local offsetY = noiseY * (CONFIG.SWIM_RADIUS * 2)

	return self.StartPosition + (self.PlaneRight * offsetX) + (self.PlaneUp * offsetY)
end

return FishClient
