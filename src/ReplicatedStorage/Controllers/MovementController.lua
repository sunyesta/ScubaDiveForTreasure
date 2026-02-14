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
local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)
local SwimmingUpgrades = require(ReplicatedStorage.Common.GameInfo.SwimmingUpgrades)

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
MovementController._MovmentPlaneNormal = Property.new(nil) -- Vector3 if in 2D mode or nil if in 3D mode
MovementController._MovementPlaneOrigin = Property.new(nil) -- Vector3 if in 2D mode or nil if in 3D mode

MovementController.DEFAULT_SWIMMING_FRICTION_WEIGHT = 0.5

MovementController.CurrentMovementMode = Property.ReadOnly(MovementController._CurrentMovementMode)
MovementController.CharacterStunned = Property.new(false)
MovementController.SwimmingFrictionWeight = Property.new(MovementController.DEFAULT_SWIMMING_FRICTION_WEIGHT)

MovementController.SwimSpeed = Property.new(20)

local movementTrove = Trove.new()

-- Constants for 3D Movement
local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

function MovementController.GameStart()
	print("MovementController: Game Start")

	-- Toggle key binding (P)
	local keyConnection = Keyboard.KeyUp:Connect(function(key)
		-- Prevent mode switching if stunned
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

	-- Handle Stun Effects globally (specifically for 3D mode properties)
	MovementController.CharacterStunned.Changed:Connect(function(isStunned)
		local currentMode = MovementController._CurrentMovementMode:Get()

		-- If we are in 3D mode, we must manually disable Humanoid stats
		if currentMode == MovementModes.Moving3D then
			local character = Player.Character
			local humanoid = character and character:FindFirstChild("Humanoid")

			if humanoid then
				humanoid.WalkSpeed = isStunned and 0 or DEFAULT_WALK_SPEED
				humanoid.JumpPower = isStunned and 0 or DEFAULT_JUMP_POWER
			end
		end

		-- Note: 2D mode handles stun checks inside its own RenderStepped loop
	end)
end

function MovementController._Moving3D()
	print("Initializing Normal Movement")

	movementTrove:Clean()

	MovementController._CurrentMovementMode:Set(MovementModes.Moving3D)
	MovementController._MovementPlaneOrigin:Set(nil)
	MovementController._MovementPlaneOrigin:Set(nil)

	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Restore default humanoid state
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	-- Apply correct speed based on current stun status
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

	-- Camera Logic
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

	local entryDampening = 0.1 -- How much momentum is kept when entering water (0 to 1)
	local turnResponsiveness = 200 -- Controls how fast the character model physically rotates

	-- Track Velocity as a Vector3 now, not just speed
	local currentMoveVelocity = Vector3.zero
	local isInWater = false

	-- 2. Modify Physics/Controls
	humanoid.AutoRotate = false

	-- Stop current momentum (Only when initializing mode)
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
	linearVelocity.MaxForce = 100000
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

	-- 4. Setup Plane Lock (Restricts depth movement) using World2DUtils
	movementTrove:Add(World2DUtils.ConstrainToPlane(rootPart, planeOrigin, planeNormal))

	-- 5. Swimming Animation & Zone Detection
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

	local waterParts = CollectionService:GetTagged("Water")

	if #waterParts > 0 then
		local waterZone = Zone.new(waterParts)
		movementTrove:Add(waterZone, "destroy")

		waterZone.localPlayerEntered:Connect(function()
			isInWater = true

			-- Capture entrance momentum
			if rootPart then
				-- We retain a percentage of the existing velocity so you don't stop instantly
				currentMoveVelocity = rootPart.AssemblyLinearVelocity * entryDampening
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

		if waterZone:findLocalPlayer() then
			isInWater = true
			if swimTrack then
				swimTrack:Play()
			end
		end
	end

	-- 6. Update Loop
	local updateConnection = RunService.RenderStepped:Connect(function(dt)
		if not isInWater then
			linearVelocity.MaxForce = 0
			alignOrientation.Enabled = false
			currentMoveVelocity = Vector3.zero
			return
		end

		-- Check for Stun status
		local isStunned = MovementController.CharacterStunned:Get()

		linearVelocity.MaxForce = 100000
		alignOrientation.Enabled = true -- Keep enabled to maintain rotation, or disable if you want them limp

		local moveDir = humanoid.MoveDirection
		local targetDir = Vector3.zero
		local targetVelocity = Vector3.zero

		-- Remap Inputs for 2D Swimming (Only if NOT stunned)
		if not isStunned and moveDir.Magnitude > 0.01 then
			local camCF = Camera.CFrame

			-- 1. Decompose Input relative to Camera
			local relInput = camCF:VectorToObjectSpace(moveDir)
			local inputRight = relInput.X
			local inputUp = -relInput.Z -- Map Forward (W) to Up intent

			-- 2. Define Plane Basis Vectors
			-- Plane Right: Camera Right projected onto Plane
			local planeRight = camCF.RightVector
			planeRight = (planeRight - planeRight:Dot(planeNormal) * planeNormal)
			if planeRight.Magnitude > 0.001 then
				planeRight = planeRight.Unit
			end

			-- Plane Up: World Up projected onto Plane (allows W to move Up against gravity)
			local planeUp = Vector3.yAxis
			planeUp = (planeUp - planeUp:Dot(planeNormal) * planeNormal)

			-- Fallback: If plane is horizontal, use Camera Up
			if planeUp.Magnitude < 0.001 then
				planeUp = camCF.UpVector
				planeUp = (planeUp - planeUp:Dot(planeNormal) * planeNormal)
			end
			if planeUp.Magnitude > 0.001 then
				planeUp = planeUp.Unit
			end

			-- 3. Synthesize Direction
			local combinedDir = (planeRight * inputRight) + (planeUp * inputUp)

			if combinedDir.Magnitude > 0.01 then
				targetDir = combinedDir.Unit
				targetVelocity = targetDir * swimSpeed
			end
		elseif isStunned then
			-- If stunned, target velocity is zero (stops movement)
			targetVelocity = Vector3.zero
		end

		-- Update Rotation: Only rotate if we have a target direction and are NOT stunned
		-- (Optional: You can remove the 'not isStunned' check if you want them to face input even while stunned)
		if not isStunned and targetDir.Magnitude > 0.01 then
			local look = targetDir
			local right = planeNormal

			-- Calculate Up vector orthogonal to right and look
			local up = right:Cross(look).Unit

			-- Recalculate Right to ensure strict orthogonality
			local rightOrtho = look:Cross(up).Unit

			-- Construct CFrame from Right, Up, and Back (-Look) vectors
			local targetCFrame = CFrame.fromMatrix(rootPart.Position, rightOrtho, up, -look)
			alignOrientation.CFrame = targetCFrame
		end

		-- Update Velocity: Lerp the VECTOR, not just the speed
		-- This allows momentum to override direction
		currentMoveVelocity = currentMoveVelocity:Lerp(
			targetVelocity,
			math.clamp(dt * MovementController.SwimmingFrictionWeight:Get(), 0, 1)
		)

		-- Apply velocity in World Space
		linearVelocity.VectorVelocity = currentMoveVelocity
	end)

	movementTrove:Add(updateConnection)

	movementTrove:Add(function()
		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
			-- Reset WalkSpeed on exit just in case
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			humanoid.JumpPower = DEFAULT_JUMP_POWER
		end
	end)
end

return MovementController
