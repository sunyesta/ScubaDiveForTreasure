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
local Cullable = require(ReplicatedStorage.NonWallyPackages.Cullable)

-- Type Definitions
type FishConfig = {
	SWIM_RADIUS: number,
	SWIM_SPEED: number,
	LOOK_AHEAD: number,
	WALL_BUFFER: number,
	BANK_FACTOR: number, -- How much the fish leans into turns
	LERP_SPEED: number, -- Visual smoothing factor
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

	-- Attributes
	self.RandomSeed = self.Instance:GetAttribute("RandomSeed") or math.random(1, 10000)

	-- Physics Setup
	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RayParams.FilterDescendantsInstances = { self.Instance }
	self.RayParams.IgnoreWater = true
	self.RayParams.CollisionGroup = GameEnums.CollisionGroups.NoCharacters

	self.Instance:AddTag("DropPart")
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

	-- Setup Culling
	-- We track the entire swim radius so the fish doesn't pop in/out
	-- when swimming near the edge of the zone.
	local cullRadius = CONFIG.SWIM_RADIUS + CONFIG.FISH_SIZE + CONFIG.VISIBILITY_PADDING

	-- We use the static constructor for Sphere culling
	local cullable = self._Trove:Add(Cullable.NewForSphere(self.StartPosition, cullRadius))

	-- Observe visibility
	cullable:Observe(function(target, visibleTrove)
		-- This callback runs when the fish's zone enters the screen
		-- visibleTrove is automatically cleaned when it leaves the screen

		local isFirstFrame = true

		visibleTrove:Connect(RunService.Heartbeat, function(dt: number)
			-- If this is the first frame of visibility, we "snap" to position
			-- to prevent lerping from the last known position (teleporting visual)
			self:UpdateMovement(dt, isFirstFrame)
			isFirstFrame = false
		end)
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
