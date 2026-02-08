local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

-- Adjust these paths as necessary for your project structure
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Input = require(ReplicatedStorage.Packages.Input)
local Cameras = require(ReplicatedStorage.Common.Modules.Cameras)
local GameEnums = require(ReplicatedStorage.Common.GameInfo.GameEnums)
local Cinemachine = require(ReplicatedStorage.NonWallyPackages.Cinemachine)
local Zone = require(ReplicatedStorage.NonWallyPackages.Zone)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)

local swimmingAnimation = GetAssetByName("FishSwim")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Keyboard = Input.Keyboard.new()

local MovementModes = {
	Normal = "Normal",
	Moving2D = "Moving2D",
}

local MovementController = {}
MovementController.MovementModes = MovementModes
MovementController.CurrentMovementMode = Property.new(nil)

MovementController.SwimSpeed = Property.new(50)

function MovementController.GameStart()
	print("MovementController: Game Start")

	local currentMovementTrove = Trove.new()

	MovementController.CurrentMovementMode:Observe(function(currentMovementMode)
		currentMovementTrove:Clean()

		print("Mode changed to:", currentMovementMode)

		if currentMovementMode == MovementModes.Normal then
			currentMovementTrove:Add(MovementController._NormalMovement())
		elseif currentMovementMode == MovementModes.Moving2D then
			currentMovementTrove:Add(MovementController._Moving2D())
		elseif currentMovementMode == nil then
			-- Initial nil state, or reset
		else
			warn("Unknown movement mode: " .. tostring(currentMovementMode))
		end
	end)

	-- Toggle key binding (P)
	local keyConnection = Keyboard.KeyUp:Connect(function(key)
		if key == Enum.KeyCode.P then
			if MovementController.CurrentMovementMode:Get() == MovementModes.Normal then
				MovementController.CurrentMovementMode:Set(MovementModes.Moving2D)
			else
				MovementController.CurrentMovementMode:Set(MovementModes.Normal)
			end
		end
	end)

	-- Initialize default mode
	MovementController.CurrentMovementMode:Set(MovementModes.Normal)

	return function()
		currentMovementTrove:Destroy()
		keyConnection:Disconnect()
	end
end

function MovementController._NormalMovement()
	local trove = Trove.new()
	print("Initializing Normal Movement")

	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Restore default humanoid state
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	return trove
end

function MovementController._Moving2D()
	local trove = Trove.new()
	print("Initializing 2D Movement")

	-- Camera Logic
	Cameras.PlayerCamera2D.Priority = GameEnums.CameraPriorities.PlayerCameraOverride
	Cinemachine.Brain:RefreshPriority()
	trove:Add(function()
		Cameras.PlayerCamera2D.Priority = GameEnums.CameraPriorities.Off
		Cinemachine.Brain:RefreshPriority()
	end)

	local character = Player.Character
	if not character then
		return trove
	end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		return trove
	end

	-- 1. Configuration & State
	-- Defined early so they can be captured by Zone events
	local swimSpeed = 50
	local verticalSpeed = 50
	local momentumFactor = 2 -- Lower = driftier/slippery, Higher = snappier
	local entryDampening = 0.2 -- How much momentum is kept when entering water (0 to 1)

	MovementController.SwimSpeed:Observe(function(newSwimSpeed)
		swimSpeed = newSwimSpeed
		verticalSpeed = newSwimSpeed
	end)

	local currentSwimVelocity = Vector3.zero
	local isInWater = false -- Track if player is in water

	-- 2. Modify Physics/Controls
	humanoid.AutoRotate = false

	-- Stop current momentum (Only when initializing mode, not when entering water)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	-- 3. Setup Physics Movers (Swimming)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SwimAttachment"
	attachment.Parent = rootPart
	trove:Add(attachment)

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "SwimVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = 100000
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = rootPart
	trove:Add(linearVelocity)

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 100000
	alignOrientation.Responsiveness = 20
	alignOrientation.Parent = rootPart
	trove:Add(alignOrientation)

	-- 4. Setup Plane Lock (Restricts depth movement)
	local planeLockAttachment = Instance.new("Attachment")
	planeLockAttachment.Name = "PlaneLockAttachment"
	planeLockAttachment.Parent = rootPart
	trove:Add(planeLockAttachment)

	local planeConstraint = Instance.new("LinearVelocity")
	planeConstraint.Name = "PlaneConstraint"
	planeConstraint.Attachment0 = planeLockAttachment
	planeConstraint.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	planeConstraint.MaxAxesForce = Vector3.new(0, 0, 1000000) -- Lock Z axis only (relative to attachment)
	planeConstraint.VectorVelocity = Vector3.zero
	planeConstraint.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	planeConstraint.Parent = rootPart
	trove:Add(planeConstraint)

	-- 5. Swimming Animation & Zone Detection
	local animator = humanoid:FindFirstChild("Animator")
	local swimTrack = nil

	-- Load animation track
	if animator and swimmingAnimation then
		swimTrack = animator:LoadAnimation(swimmingAnimation)
		swimTrack.Looped = true
		trove:Add(function()
			if swimTrack then
				swimTrack:Stop()
			end
		end)
	end

	-- Detect "Water" tagged parts
	local waterParts = CollectionService:GetTagged("Water")

	if #waterParts > 0 then
		local waterZone = Zone.new(waterParts)
		trove:Add(waterZone, "destroy")

		-- Handle Zone Events
		waterZone.localPlayerEntered:Connect(function()
			isInWater = true

			-- Capture and dampen entrance momentum
			if rootPart then
				currentSwimVelocity = rootPart.AssemblyLinearVelocity * entryDampening
			end

			if swimTrack then
				swimTrack:Play()
			end
		end)

		waterZone.localPlayerExited:Connect(function()
			isInWater = false
			if swimTrack then
				swimTrack:Stop()
			end
		end)

		-- Initial check: If we spawned inside water
		if waterZone:findLocalPlayer() then
			isInWater = true
			if swimTrack then
				swimTrack:Play()
			end
		end
	end

	-- 6. Update Loop
	local updateConnection = RunService.RenderStepped:Connect(function(dt)
		-- Determine Plane Vectors (Used for both swimming logic and plane locking)
		local lookVector = Camera.CFrame.LookVector
		local rightVector = Camera.CFrame.RightVector

		local flatLook = (lookVector * Vector3.new(1, 0, 1))
		local flatRight = (rightVector * Vector3.new(1, 0, 1))

		if flatLook.Magnitude > 0 then
			flatLook = flatLook.Unit
		else
			flatLook = Vector3.zAxis
		end

		if flatRight.Magnitude > 0 then
			flatRight = flatRight.Unit
		else
			flatRight = Vector3.xAxis
		end

		-- Update Plane Lock Orientation
		planeLockAttachment.WorldCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook)

		-- If not in water, disable custom swimming forces
		if not isInWater then
			linearVelocity.MaxForce = 0
			alignOrientation.Enabled = false
			currentSwimVelocity = Vector3.zero
			return
		end

		-- Enable forces when in water
		linearVelocity.MaxForce = 100000
		alignOrientation.Enabled = true

		local moveDir = humanoid.MoveDirection
		local targetVelocity = Vector3.zero

		if moveDir.Magnitude > 0.01 then
			local forwardInput = moveDir:Dot(flatLook)
			local rightInput = moveDir:Dot(flatRight)

			-- Up/Down controls altitude
			local vertical = Vector3.new(0, forwardInput * verticalSpeed, 0)
			-- Left/Right controls sideways movement
			local horizontal = rightVector * (rightInput * swimSpeed)

			targetVelocity = vertical + horizontal

			if horizontal.Magnitude > 0.1 then
				local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + horizontal)
				alignOrientation.CFrame = targetCFrame
			end
		end

		-- Apply Momentum Drift (Linear Interpolation)
		-- Lerps current velocity towards target velocity based on time and momentum factor
		currentSwimVelocity = currentSwimVelocity:Lerp(targetVelocity, math.clamp(dt * momentumFactor, 0, 1))
		linearVelocity.VectorVelocity = currentSwimVelocity
	end)

	trove:Add(updateConnection)

	-- Cleanup
	trove:Add(function()
		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
		end
	end)

	return trove
end

function MovementController.Start2DMovement() end

return MovementController
