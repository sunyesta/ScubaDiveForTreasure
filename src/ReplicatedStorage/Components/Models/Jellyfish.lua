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
local Treasure = require(ReplicatedStorage.Common.Components.Models.Treasure)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local MovementController = require(ReplicatedStorage.Common.Controllers.MovementController)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local SpawnVisualEffect = require(ReplicatedStorage.Common.Modules.GameUtils.SpawnVisualEffect)

Player = Players.LocalPlayer

-- Type Definitions
type JellyConfig = {
	SWIM_RADIUS: number,
	SWIM_SPEED: number,
	LOOK_AHEAD: number,
	WALL_BUFFER: number,
	PULSE_FREQ: number, -- How fast they bob up and down
	PULSE_AMP: number, -- How far they bob
	LERP_SPEED: number, -- Lower = floatier movement
	JELLY_SIZE: number, -- Approximate size for culling
	VISIBILITY_PADDING: number,
	TILT_AMOUNT: number, -- New: How much it leans into the movement
}

local CONFIG: JellyConfig = {
	SWIM_RADIUS = 12,
	SWIM_SPEED = 0.15, -- Much slower than fish
	LOOK_AHEAD = 1.0, -- Look further ahead for smoother turns
	WALL_BUFFER = 2.0,
	PULSE_FREQ = 1.5, -- Gentle pulsing rhythm
	PULSE_AMP = 1.5, -- Vertical bob height
	LERP_SPEED = 2.0, -- Very smooth, floaty transitions
	JELLY_SIZE = 5,
	VISIBILITY_PADDING = 10,
	TILT_AMOUNT = 0.1, -- Strength of the tilt
}

local JellyfishClient = Component.new({
	Tag = "Jellyfish",
	Ancestors = { Workspace },
})

function JellyfishClient:Construct()
	self._Trove = Trove.new()

	-- State
	self.MovementPlaneOrigin = World2DUtils.DefaultPlaneOrigin
	self.MovementPlaneNormal = World2DUtils.DefaultPlaneNormal
	self.StartPosition = Vector3.zero -- Assigned on Load

	-- Attributes
	self.RandomSeed = self.Instance:GetAttribute("RandomSeed") or math.random(1, 10000)

	-- Physics Setup
	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RayParams.FilterDescendantsInstances = { self.Instance }
	self.RayParams.IgnoreWater = true
	self.RayParams.CollisionGroup = GameEnums.CollisionGroups.NoCharacters
end

function JellyfishClient:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))
	partStreamable:Observe(function(rootPart)
		if rootPart then
			self:OnRootPartLoaded(rootPart)
		end
	end)
end

function JellyfishClient:Stop()
	self._Trove:Clean()
end

function JellyfishClient:OnRootPartLoaded(rootPart: BasePart)
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
	local cullRadius = CONFIG.SWIM_RADIUS + CONFIG.JELLY_SIZE + CONFIG.VISIBILITY_PADDING
	local cullable = self._Trove:Add(Cullable.NewForSphere(self.StartPosition, cullRadius))

	-- Observe visibility
	cullable:Observe(function(target, visibleTrove)
		local isFirstFrame = true

		visibleTrove:Connect(RunService.Heartbeat, function(dt: number)
			self:UpdateMovement(dt, isFirstFrame)
			isFirstFrame = false
		end)

		visibleTrove:Add(rootPart.Touched:Connect(function(hit)
			self:HandleTouched(hit)
		end))
	end)
end

function JellyfishClient:UpdateMovement(dt: number, snap: boolean?)
	-- Sync time with server
	local t = Workspace:GetServerTimeNow() % 100000
	local seedOffset = self.RandomSeed % 10000

	-- 1. Calculate Target Position (Noise + Pulse)
	local targetPos = self:GetNoisePosition(t, seedOffset)

	-- Apply "Jelly Pulse" (Vertical Sine Wave)
	-- This adds the up/down bobbing motion relative to the plane's Up vector
	local pulseOffset = math.sin(t * CONFIG.PULSE_FREQ) * CONFIG.PULSE_AMP
	targetPos = targetPos + (self.PlaneUp * pulseOffset)

	-- 2. Wall Avoidance (Slide along wall)
	local toTarget = targetPos - self.Instance:GetPivot().Position

	if not snap and toTarget.Magnitude > 0.001 then
		local rayResult = Workspace:Raycast(self.Instance:GetPivot().Position, toTarget, self.RayParams)
		if rayResult then
			local surfaceNormal = rayResult.Normal
			local slideVector = toTarget - (surfaceNormal * toTarget:Dot(surfaceNormal))
			targetPos = rayResult.Position + slideVector + (surfaceNormal * CONFIG.WALL_BUFFER)
		end
	end

	-- 3. Calculate Orientation (Face plane normal + Tilt into movement)
	-- Determine the tilt vector. If we are snapping (teleporting), use no tilt.
	local tiltedUp = self.PlaneUp
	if not snap then
		local moveVector = targetPos - self.Instance:GetPivot().Position
		-- Bias the Up vector in the direction of movement to create a lean
		tiltedUp = (self.PlaneUp + (moveVector * CONFIG.TILT_AMOUNT)).Unit
	end

	-- The jellyfish faces the plane normal, but its "Up" vector tilts towards its destination
	local targetCFrame = CFrame.lookAt(targetPos, targetPos + self.MovementPlaneNormal, tiltedUp)

	-- 4. Apply Position and Rotation
	if snap then
		self.Instance:PivotTo(targetCFrame)
	else
		-- Smooth lerp for that "underwater resistance" feel
		local currentCFrame = self.Instance:GetPivot()
		local smoothCFrame = currentCFrame:Lerp(targetCFrame, math.min(dt * CONFIG.LERP_SPEED, 1))
		self.Instance:PivotTo(smoothCFrame)
	end
end

function JellyfishClient:GetNoisePosition(t: number, seed: number): Vector3
	local noiseX = math.noise(t * CONFIG.SWIM_SPEED, seed, 0)
	local noiseY = math.noise(seed, t * CONFIG.SWIM_SPEED, 1)

	-- Multiply by 2 because noise is roughly -0.5 to 0.5
	local offsetX = noiseX * (CONFIG.SWIM_RADIUS * 2)
	local offsetY = noiseY * (CONFIG.SWIM_RADIUS * 2)

	return self.StartPosition + (self.PlaneRight * offsetX) + (self.PlaneUp * offsetY)
end

function JellyfishClient:HandleTouched(hit)
	if
		(Player.Character and Player.Character:IsAncestorOf(hit))
		or InstanceUtils.FindFirstAncestorWithTag(hit, "Treasure")
	then
		local character = Player.Character
		local treasure = Treasure.HoldingTreasure:Get()

		if character:GetAttribute("BeingZapped") == true then
			return
		else
			character:SetAttribute("BeingZapped", true)
		end

		local zapSound = GetAssetByName("ZapSound"):Clone()
		zapSound.Parent = character
		zapSound:Play()

		local trove = Trove.new()

		trove:Add(SpawnVisualEffect.Electricity(character.HumanoidRootPart))

		MovementController.CharacterStunned:Set(true)
		MovementController.SwimmingFrictionWeight:Set(3)

		if treasure then
			treasure:Release()
			trove:Add(SpawnVisualEffect.Electricity(treasure.Instance.PrimaryPart))
		end

		task.spawn(function()
			task.wait(2)
			trove:Clean()
			MovementController.SwimmingFrictionWeight:Set(MovementController.DEFAULT_SWIMMING_FRICTION_WEIGHT)
			MovementController.CharacterStunned:Set(false)
			character:SetAttribute("BeingZapped", false)
		end)
	end
end

return JellyfishClient
