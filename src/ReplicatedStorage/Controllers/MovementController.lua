local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Adjust these paths as necessary for your project structure
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Input = require(ReplicatedStorage.Packages.Input)
local Cameras = require(ReplicatedStorage.Common.Modules.Cameras)
local GameEnums = require(ReplicatedStorage.Common.GameInfo.GameEnums)
local Cinemachine = require(ReplicatedStorage.NonWallyPackages.Cinemachine)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)
local SwimmingUpgrades = require(ReplicatedStorage.Common.GameInfo.SwimmingUpgrades)

-- IMPORTANT: Require the WaterController so we can listen to its state
local WaterController = require(ReplicatedStorage.Common.Controllers.WaterController)

local swimmingAnimation = GetAssetByName("Swim")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Keyboard = Input.Keyboard.new()

local MovementModes = {
	Moving3D = "Moving3D",
	Moving2D = "Moving2D",
}

local MovementController = {}
MovementController.MovementModes = MovementModes
MovementController._CurrentMovementMode = Property.new(MovementModes.Moving3D)
MovementController._MovmentPlaneNormal = Property.new(nil)
MovementController._MovementPlaneOrigin = Property.new(nil)

-- NEW: Expose the current velocity state so external scripts can influence it
MovementController._CurrentMoveVelocity = Vector3.zero

MovementController.DEFAULT_SWIMMING_FRICTION_WEIGHT = 0.5

MovementController.CurrentMovementMode = Property.ReadOnly(MovementController._CurrentMovementMode)
MovementController.CharacterStunned = Property.new(false)
MovementController.SwimmingFrictionWeight = Property.new(MovementController.DEFAULT_SWIMMING_FRICTION_WEIGHT)

MovementController.SwimSpeed = Property.new(20)

local movementTrove = Trove.new()

-- Constants for 3D Movement
local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

-- [[ PUBLIC API ]] --

-- Use this function from other scripts to apply external forces/knockback!
function MovementController.ApplyImpulse(impulse: Vector3)
	if MovementController._CurrentMovementMode:Get() == MovementModes.Moving2D then
		-- In 2D Swimming mode, add to our tracked velocity.
		-- The existing RenderStepped loop will naturally dampen this via Lerp, creating a "drift"!
		MovementController._CurrentMoveVelocity += impulse
	else
		-- In 3D Walking mode, apply the impulse directly to standard physics.
		local character = Player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.AssemblyLinearVelocity += impulse
		end
	end
end

function MovementController.GameStart()
	print("MovementController: Game Start")

	local keyConnection = Keyboard.KeyUp:Connect(function(key)
		if MovementController.CharacterStunned:Get() then
			return
		end

		if key == Enum.KeyCode.P then
			if MovementController._CurrentMovementMode:Get() == MovementModes.Moving3D then
				MovementController._Moving2D(workspace.MAP.WaterPlane.Position, World2DUtils.DefaultPlaneNormal)
			else
				MovementController._Moving3D()
			end
		end
	end)

	MovementController.CharacterStunned.Changed:Connect(function(isStunned)
		local currentMode = MovementController._CurrentMovementMode:Get()

		if currentMode == MovementModes.Moving3D then
			local character = Player.Character
			local humanoid = character and character:FindFirstChild("Humanoid")

			if humanoid then
				humanoid.WalkSpeed = isStunned and 0 or DEFAULT_WALK_SPEED
				humanoid.JumpPower = isStunned and 0 or DEFAULT_JUMP_POWER
			end
		end
	end)
end

function MovementController._Moving3D()
	print("Initializing Normal Movement")

	movementTrove:Clean()

	MovementController._CurrentMovementMode:Set(MovementModes.Moving3D)
	MovementController._MovementPlaneOrigin:Set(nil)
	MovementController._MovmentPlaneNormal:Set(nil)

	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	local isStunned = MovementController.CharacterStunned:Get()
	humanoid.WalkSpeed = isStunned and 0 or DEFAULT_WALK_SPEED
	humanoid.JumpPower = isStunned and 0 or DEFAULT_JUMP_POWER
end

function MovementController._Moving2D(planeOrigin, planeNormal)
	print("Initializing 2D Movement")

	movementTrove:Clean()

	MovementController._CurrentMovementMode:Set(MovementModes.Moving2D)
	MovementController._MovementPlaneOrigin:Set(planeOrigin)
	MovementController._MovmentPlaneNormal:Set(planeNormal)
	MovementController._CurrentMoveVelocity = Vector3.zero

	Cameras.PlayerCamera2D.Priority = GameEnums.CameraPriorities.PlayerCameraOverride
	Cinemachine.Brain:RefreshPriority()
	movementTrove:Add(function()
		Cameras.PlayerCamera2D.Priority = GameEnums.CameraPriorities.Off
		Cinemachine.Brain:RefreshPriority()
	end)

	local character = Player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		return
	end

	-- 1. Configuration & State
	local swimSpeed = 25
	local entryDampening = 0.1
	local turnResponsiveness = 200

	-- === BOUNCE SETTINGS ===
	local BOUNCE_MULTIPLIER = 0.5
	local BOUNCE_STUN_DURATION = 0.25
	local BOUNCE_CAST_DISTANCE = 1.5

	-- === WATER EXIT SETTINGS ===
	local EXIT_BOOST_MULTIPLIER = 1.25
	local MIN_EXIT_UPWARD_VELOCITY = 30
	local EXIT_BOOST_DURATION = 0.25

	local isBouncing = false
	local bounceTimer = 0

	local exitBoostTimer = 0
	local exitBoostVelocityY = 0

	local bounceParams = RaycastParams.new()
	bounceParams.CollisionGroup = GameEnums.CollisionGroups.NoCharacters
	bounceParams.IgnoreWater = true
	-- =======================

	-- 2. Modify Physics/Controls
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	-- 3. Setup Physics Movers (Swimming)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SwimAttachment"
	attachment.Parent = rootPart
	movementTrove:Add(attachment)

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "SwimVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = 15000
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = rootPart
	movementTrove:Add(linearVelocity)

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 100000
	alignOrientation.Responsiveness = turnResponsiveness
	alignOrientation.Parent = rootPart
	movementTrove:Add(alignOrientation)

	-- 4. Setup Plane Lock
	movementTrove:Add(World2DUtils.ConstrainToPlane(rootPart, planeOrigin, planeNormal))

	-- 5. Swimming Animation & Water State Listening
	local animator = humanoid:FindFirstChild("Animator")
	local swimTrack = nil

	if animator and swimmingAnimation then
		swimTrack = animator:LoadAnimation(swimmingAnimation)
		swimTrack.Looped = true
		movementTrove:Add(function()
			if swimTrack then
				swimTrack:Stop()
			end
		end)
	end

	-- Dynamically handle transitioning in and out of water
	movementTrove:Add(WaterController.PlayerInWater.Changed:Connect(function(inWater)
		if inWater then
			-- Entering Water
			if rootPart then
				MovementController._CurrentMoveVelocity = rootPart.AssemblyLinearVelocity * entryDampening
			end
			humanoid.PlatformStand = true
			humanoid.AutoRotate = false

			if swimTrack then
				swimTrack:Play()
			end
		else
			-- Exiting Water
			if swimTrack then
				swimTrack:Stop()
			end

			alignOrientation.Enabled = false
			linearVelocity.MaxForce = 0

			if rootPart then
				local lookVector = rootPart.CFrame.LookVector
				local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
				if flatLook.Magnitude > 0.001 then
					rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook)
				end

				rootPart.AssemblyAngularVelocity = Vector3.zero

				local exitVelocity = MovementController._CurrentMoveVelocity

				if exitVelocity.Y > 1 then
					local targetY = math.max(exitVelocity.Y * EXIT_BOOST_MULTIPLIER, MIN_EXIT_UPWARD_VELOCITY)
					exitVelocity = Vector3.new(exitVelocity.X, targetY, exitVelocity.Z)

					exitBoostTimer = EXIT_BOOST_DURATION
					exitBoostVelocityY = targetY
				else
					exitBoostTimer = 0
				end

				rootPart.AssemblyLinearVelocity = exitVelocity
			end

			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end))

	-- Initial state check
	if WaterController.PlayerInWater:Get() then
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		if swimTrack then
			swimTrack:Play()
		end
	else
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end

	-- 6. Update Loop
	local updateConnection = RunService.RenderStepped:Connect(function(dt)
		local inWater = WaterController.PlayerInWater:Get()

		if not inWater then
			linearVelocity.MaxForce = 0
			alignOrientation.Enabled = false
			MovementController._CurrentMoveVelocity = Vector3.zero

			if exitBoostTimer > 0 and rootPart then
				exitBoostTimer -= dt
				local currentVel = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, exitBoostVelocityY, currentVel.Z)
				rootPart.AssemblyAngularVelocity = Vector3.zero
			end

			return
		end

		exitBoostTimer = 0

		local isStunned = MovementController.CharacterStunned:Get()
		linearVelocity.MaxForce = 15000
		alignOrientation.Enabled = true

		local moveDir = humanoid.MoveDirection
		local targetDir = Vector3.zero
		local targetVelocity = Vector3.zero

		-- === BOUNCE TIMER LOGIC ===
		if isBouncing then
			bounceTimer -= dt
			if bounceTimer <= 0 then
				isBouncing = false
			end
		end

		-- === BOUNCE DETECTION LOGIC ===
		if not isBouncing and MovementController._CurrentMoveVelocity.Magnitude > 1 then
			local checkDirection = MovementController._CurrentMoveVelocity.Unit * BOUNCE_CAST_DISTANCE
			local hit = Workspace:Spherecast(rootPart.Position, 1.5, checkDirection, bounceParams)

			if hit and hit.Instance.CanCollide then
				local V = MovementController._CurrentMoveVelocity
				local N = hit.Normal
				local reflection = V - (2 * V:Dot(N) * N)

				local BounceMultiplier = hit.Instance:GetAttribute("BounceMultiplier") or BOUNCE_MULTIPLIER

				reflection = reflection - (reflection:Dot(planeNormal) * planeNormal)
				MovementController._CurrentMoveVelocity = reflection * BounceMultiplier
				isBouncing = true
				bounceTimer = BOUNCE_STUN_DURATION
			end
		end

		-- Remap Inputs for 2D Swimming
		if not isStunned and not isBouncing and moveDir.Magnitude > 0.01 then
			local camCF = Camera.CFrame

			local relInput = camCF:VectorToObjectSpace(moveDir)
			local inputRight = relInput.X
			local inputUp = -relInput.Z

			local planeRight = camCF.RightVector
			planeRight = (planeRight - planeRight:Dot(planeNormal) * planeNormal)
			if planeRight.Magnitude > 0.001 then
				planeRight = planeRight.Unit
			end

			local planeUp = Vector3.yAxis
			planeUp = (planeUp - planeUp:Dot(planeNormal) * planeNormal)

			if planeUp.Magnitude < 0.001 then
				planeUp = camCF.UpVector
				planeUp = (planeUp - planeUp:Dot(planeNormal) * planeNormal)
			end
			if planeUp.Magnitude > 0.001 then
				planeUp = planeUp.Unit
			end

			local combinedDir = (planeRight * inputRight) + (planeUp * inputUp)

			if combinedDir.Magnitude > 0.01 then
				targetDir = combinedDir.Unit
				targetVelocity = targetDir * swimSpeed
			end
		elseif isStunned or isBouncing then
			targetVelocity = Vector3.zero
		end

		-- Update Rotation
		if not isStunned and targetDir.Magnitude > 0.01 then
			local look = targetDir
			local right = planeNormal

			local up = right:Cross(look).Unit
			local rightOrtho = look:Cross(up).Unit

			local targetCFrame = CFrame.fromMatrix(rootPart.Position, rightOrtho, up, -look)
			alignOrientation.CFrame = targetCFrame
		end

		-- Update Velocity
		MovementController._CurrentMoveVelocity = MovementController._CurrentMoveVelocity:Lerp(
			targetVelocity,
			math.clamp(dt * MovementController.SwimmingFrictionWeight:Get(), 0, 1)
		)

		-- Apply velocity
		linearVelocity.VectorVelocity = MovementController._CurrentMoveVelocity
	end)

	movementTrove:Add(updateConnection)

	movementTrove:Add(function()
		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			humanoid.JumpPower = DEFAULT_JUMP_POWER
		end
	end)
end

return MovementController
