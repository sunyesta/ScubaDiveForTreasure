local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ComponentBase = require(script.Parent.ComponentBase)
local MathUtils = require(script.Parent.Parent.Utils.MathUtils)
local MultiTouch = require(ReplicatedStorage.NonWallyPackages.MultiTouch)
local ConsoleVisualizer = require(ReplicatedStorage.NonWallyPackages.ConsoleVisualizer)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)

-- ConsoleVisualizer.new(Players.LocalPlayer.PlayerGui:WaitForChild("Console"):WaitForChild("Frame"))

-- [BODY] Trackball: Orbit camera with collision, zoom, damping, and humanoid handling
local Trackball = setmetatable({}, ComponentBase)
Trackball.__index = Trackball

-- Constants
local ORIG_TRANSPARENCY_ATTR = "Trackball_OriginalTransparency"
local MIN_VISIBLE_DISTANCE = 2.5
local KEYBOARD_ROTATION_SPEED = 2.0 -- Radians per second

-- Helper: Raycast that can penetrate specific parts based on a filter
local function FindNextValidHit(rayOrigin: Vector3, rayDirection: Vector3, raycastParams: RaycastParams, isValid)
	local hitCount = 0
	local maxHits = 10 -- Safety break to prevent infinite loops

	while hitCount < maxHits do
		local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if result then
			if isValid(result) then
				return result
			else
				hitCount += 1

				-- Logic to step forward through the object
				local dirUnit = rayDirection.Unit
				local dist = result.Distance

				-- Move origin slightly past the hit point (0.1 studs)
				rayOrigin = result.Position + (dirUnit * 0.1)

				-- Reduce the remaining ray vector by the distance traveled
				rayDirection = rayDirection - (dirUnit * dist)

				-- If the remaining ray is insignificant, stop
				if rayDirection.Magnitude < 0.1 then
					break
				end
			end
		else
			break
		end
	end

	return nil
end

local function DefaultCollisionFilter(part)
	local filtered = InstanceUtils.FindFirstAncestorWithTag(part, "IgnoreCamera") or part.Transparency > 0.1
	-- if not filtered then
	-- 	print("camera collided with", part)
	-- end

	return filtered
end

function Trackball.new(config)
	local self = setmetatable(ComponentBase.new(), Trackball)
	config = config or {}

	-- Configuration
	self.MinDistance = config.MinDistance or 2
	self.MaxDistance = config.MaxDistance or 50
	self.DefaultDistance = config.StartDistance or 15
	self.ZoomSpeed = config.ZoomSpeed or 4
	self.Sensitivity = config.Sensitivity or Vector2.new(0.008, 0.008) -- X, Y sensitivity
	self.Damping = config.Damping or Vector3.new(0, 0, 0) -- Yaw, Pitch, Zoom Damping
	self.FollowOffset = config.FollowOffset or Vector3.new(0, 2, 0) -- Pivot offset (e.g. Look at Head level)
	self.CollisionEnabled = config.CollisionEnabled ~= false
	self.CollisionRadius = config.CollisionRadius or 0.5
	self.CollisionFilter = config.CollisionFilter or DefaultCollisionFilter -- Function(part) -> boolean. Returns true to IGNORE collision.
	self.YLimit = config.YLimit or { Min = -1.4, Max = 1.4 } -- Radians (approx -80 to 80 degrees)
	self.MouseLock = config.MouseLock or false -- Controls if mouse stays locked when zoomed out

	-- Humanoid Handling
	self.FadeCharacter = config.FadeCharacter ~= false

	-- Internal State
	self.Yaw = 0
	self.Pitch = 0.2
	self.Distance = self.DefaultDistance

	self.TargetYaw = self.Yaw
	self.TargetPitch = self.Pitch
	self.TargetDistance = self.Distance

	-- Transparency State
	self._lastFadeTarget = nil
	self._lastTransparencyFactor = 0

	self:SetupInput()
	self:SetupCleanup()

	return self
end

function Trackball:SetupInput()
	-- Handle Zoom via Scroll Wheel
	self._trove:Connect(UserInputService.InputChanged, function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self.TargetDistance = math.clamp(
				self.TargetDistance - (input.Position.Z * self.ZoomSpeed),
				self.MinDistance,
				self.MaxDistance
			)
		end
	end)

	-- Handle Multitouch (Mobile/Tablet)
	local lastPositions = {}

	self._trove:Add(MultiTouch.TouchPositions:Observe(function(allTouchDatas)
		-- Filter touches to exclude Processed (GUI) and Thumbstick (Trackpad)
		local touchPositionsMap = MultiTouch:FilterTouchPositions(allTouchDatas, {
			Unprocessed = true,
			Gui = false,
			Thumbstick = false,
		})

		-- Convert map {[ID] = Position} to sorted array of Positions
		local sortedTouches = {}
		for id, pos in pairs(touchPositionsMap) do
			table.insert(sortedTouches, { ID = id, Position = pos })
		end
		table.sort(sortedTouches, function(a, b)
			return a.ID < b.ID
		end)

		local touchPositions = {}
		for _, data in ipairs(sortedTouches) do
			table.insert(touchPositions, data.Position)
		end

		-- Capture current 'lastPositions' before updating it, for use in delta calculation
		local prevPositions = lastPositions
		lastPositions = touchPositions

		-- 1 Finger: Orbit/Rotate
		if #touchPositions == 1 and #prevPositions == 1 then
			local delta = touchPositions[1] - prevPositions[1]

			self.TargetYaw = self.TargetYaw - (delta.X * self.Sensitivity.X)
			self.TargetPitch =
				math.clamp(self.TargetPitch - (delta.Y * self.Sensitivity.Y), self.YLimit.Min, self.YLimit.Max)

		-- 2 Fingers: Pinch to Zoom
		elseif #touchPositions == 2 and #prevPositions == 2 then
			local lastDistance = (prevPositions[2] - prevPositions[1]).Magnitude
			local curDistance = (touchPositions[2] - touchPositions[1]).Magnitude

			local zoomDelta = curDistance - lastDistance

			-- Adjust zoom sensitivity for touch (usually needs to be slower than raw pixels)
			local touchZoomSpeed = self.ZoomSpeed * 0.05

			-- Pinch out (positive delta) = Zoom In (decrease distance)
			self.TargetDistance =
				math.clamp(self.TargetDistance - (zoomDelta * touchZoomSpeed), self.MinDistance, self.MaxDistance)
		end
	end))
end

function Trackball:SetupCleanup()
	-- Restore transparency if we were hiding a character
	self._trove:Add(function()
		if self._lastFadeTarget then
			self:RestoreTransparency(self._lastFadeTarget)
		end

		-- Ensure mouse is unlocked when component is destroyed
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)
end

-- Helper to find a good pivot point (Head/Root)
function Trackball:GetPivotPosition(target)
	if not target then
		return nil
	end

	-- Prioritize HumanoidRootPart for stability (Head bobs with animation)
	if target:IsA("Model") then
		local root = target:FindFirstChild("HumanoidRootPart")
		if root then
			return root.Position
		end
		local head = target:FindFirstChild("Head")
		if head then
			return head.Position
		end
	elseif target:IsA("Humanoid") then
		local parent = target.Parent
		if parent then
			local root = parent:FindFirstChild("HumanoidRootPart")
			if root then
				return root.Position
			end
		end
	end

	return MathUtils.GetTargetPosition(target)
end

function Trackball:RestoreTransparency(character)
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			local currentOrig = part:GetAttribute(ORIG_TRANSPARENCY_ATTR)
			if currentOrig then
				part.Transparency = currentOrig
				part:SetAttribute(ORIG_TRANSPARENCY_ATTR, nil)
			end
		end
	end
end

function Trackball:UpdateTransparency(target, distance)
	if not self.FadeCharacter then
		return
	end

	local character
	if target:IsA("Model") then
		character = target
	elseif target:IsA("BasePart") then
		character = target.Parent
	elseif target:IsA("Humanoid") then
		character = target.Parent
	end

	if not character then
		return
	end

	-- If target changed, clean up the old one
	if self._lastFadeTarget and self._lastFadeTarget ~= character then
		self:RestoreTransparency(self._lastFadeTarget)
		self._lastTransparencyFactor = 0
	end
	self._lastFadeTarget = character

	-- Calculate transparency factor based on distance
	local transparencyFactor = 0
	if distance < MIN_VISIBLE_DISTANCE then
		transparencyFactor = 1 - (distance / MIN_VISIBLE_DISTANCE)
	end

	-- Optimization: Don't scan descendants if we are far away and were already fully visible
	if transparencyFactor == 0 and self._lastTransparencyFactor == 0 then
		return
	end
	self._lastTransparencyFactor = transparencyFactor

	-- Apply transparency
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local currentOrig = part:GetAttribute(ORIG_TRANSPARENCY_ATTR)

			if transparencyFactor <= 0 then
				-- Restore original
				if currentOrig then
					part.Transparency = currentOrig
					part:SetAttribute(ORIG_TRANSPARENCY_ATTR, nil)
				end
			else
				-- Fade out
				if currentOrig == nil then
					-- Store original transparency
					part:SetAttribute(ORIG_TRANSPARENCY_ATTR, part.Transparency)
					currentOrig = part.Transparency
				end

				-- Set new transparency (use math.max to never make something *more* visible than it should be)
				part.Transparency = math.max(transparencyFactor, currentOrig)
			end
		end
	end
end

function Trackball:Mutate(vcam, state, dt)
	local target = vcam.Follow
	if not target then
		return
	end

	local pivotPos = self:GetPivotPosition(target)
	if not pivotPos then
		return
	end

	pivotPos = pivotPos + self.FollowOffset

	-- 1. Input Handling
	-- Check if we are fully zoomed in (with a small epsilon buffer)
	local isFullyZoomed = self.TargetDistance <= (self.MinDistance + 0.1)

	-- Determine if mouse should be locked:
	-- 1. If config.MouseLock is true, always lock.
	-- 2. If config.MouseLock is false, only lock when fully zoomed in.
	local shouldLock = self.MouseLock or isFullyZoomed

	-- Keyboard Rotation
	if UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		self.TargetYaw = self.TargetYaw + (KEYBOARD_ROTATION_SPEED * dt)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		self.TargetYaw = self.TargetYaw - (KEYBOARD_ROTATION_SPEED * dt)
	end

	if shouldLock then
		-- First Person / Locked Mode
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

		-- Always rotate when locked, no click required
		local delta = UserInputService:GetMouseDelta()
		self.TargetYaw = self.TargetYaw - (delta.X * self.Sensitivity.X)
		self.TargetPitch =
			math.clamp(self.TargetPitch - (delta.Y * self.Sensitivity.Y), self.YLimit.Min, self.YLimit.Max)
	else
		-- Orbit Mode

		-- CHECK FOR RIGHT CLICK ORBIT:
		-- Check if we are currently right-clicking (orbiting)
		local isOrbiting = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

		-- If we were previously locked in center (from being zoomed in or a previous toggle), unlock now.
		-- FIX: We only unlock if the user is NOT orbiting. Roblox natively locks the mouse when you hold Right Click.
		-- If we force Default while right-click dragging, we fight the engine, causing the cursor to flicker
		-- and rotation (GetMouseDelta) to fail.
		if not isOrbiting and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end

		-- Standard Right-Click Orbit
		if isOrbiting then
			local delta = UserInputService:GetMouseDelta()
			self.TargetYaw = self.TargetYaw - (delta.X * self.Sensitivity.X)
			self.TargetPitch =
				math.clamp(self.TargetPitch - (delta.Y * self.Sensitivity.Y), self.YLimit.Min, self.YLimit.Max)
		end
	end

	-- 2. Damping
	local dampX = 1 - math.exp(-dt / math.max(0.001, self.Damping.X))
	local dampY = 1 - math.exp(-dt / math.max(0.001, self.Damping.Y))
	local dampZ = 1 - math.exp(-dt / math.max(0.001, self.Damping.Z))

	self.Yaw = MathUtils.Lerp(self.Yaw, self.TargetYaw, dampX)
	self.Pitch = MathUtils.Lerp(self.Pitch, self.TargetPitch, dampY)
	self.Distance = MathUtils.Lerp(self.Distance, self.TargetDistance, dampZ)

	-- 3. Calculate Position (Spherical Coordinates)
	local rotation = CFrame.Angles(0, self.Yaw, 0) * CFrame.Angles(self.Pitch, 0, 0)

	-- 4. Collision Detection
	local finalDistance = self.Distance
	if self.CollisionEnabled then
		local direction = (rotation * Vector3.new(0, 0, 1)).Unit
		local origin = pivotPos
		local rayVector = direction * self.Distance

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		-- Ignore target hierarchy
		local ignore = { target }
		if target:IsA("BasePart") or target:IsA("Humanoid") then
			table.insert(ignore, target.Parent)
		end
		rayParams.FilterDescendantsInstances = ignore

		-- Define validity check
		-- If config.CollisionFilter returns true, we IGNORE the part (passthrough), so it is invalid as a stopping point.
		local function isValidHit(result)
			if self.CollisionFilter then
				return not self.CollisionFilter(result.Instance)
			end
			return true
		end

		local result = FindNextValidHit(origin, rayVector, rayParams, isValidHit)

		if result then
			-- Push in slightly to avoid clipping near plane
			finalDistance = math.max(0.1, (result.Position - origin).Magnitude - self.CollisionRadius)
		end
	end

	-- 5. Humanoid Transparency Handling
	self:UpdateTransparency(target, finalDistance)

	local offsetVector = Vector3.new(0, 0, finalDistance)
	local finalPos = pivotPos + (rotation * offsetVector)

	-- 6. Apply to State
	state.Position = finalPos
	-- Use rotation directly to avoid instability/NaN when distance is near zero
	state.Rotation = rotation
end

return Trackball
