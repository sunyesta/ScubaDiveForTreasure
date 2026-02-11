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
MovementController.CurrentMovementMode = Property.BindToAttribute(Player, "MovementMode", MovementModes.Moving3D)
MovementController.MovmentPlaneNormal = Property.BindToAttribute(Player, "MovmentPlaneNormal", nil) -- Vector3 if in 2D mode or nil if in 3D mode
MovementController.MovementPlaneOrigin = Property.BindToAttribute(Player, "MovementPlaneOrigin", nil) -- Vector3 if in 2D mode or nil if in 3D mode

MovementController.SwimSpeed = Property.new(20)

local movementTrove = Trove.new()

function MovementController.GameStart()
	print("MovementController: Game Start")

	-- Toggle key binding (P)
	local keyConnection = Keyboard.KeyUp:Connect(function(key)
		if key == Enum.KeyCode.P then
			if MovementController.CurrentMovementMode:Get() == MovementModes.Moving3D then
				MovementController._Moving2D(Player.Character:GetPivot().Position, Vector3.new(0, 0, -1))
			else
				MovementController._Moving3D()
			end
		end
	end)
end

function MovementController._Moving3D()
	print("Initializing Normal Movement")

	movementTrove:Clean()

	MovementController.CurrentMovementMode:Set(MovementModes.Moving3D)
	MovementController.MovementPlaneOrigin:Set(nil)
	MovementController.MovementPlaneOrigin:Set(nil)

	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Restore default humanoid state
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
end
function MovementController._Moving2D(planeOrigin, planeNormal)
	print("Initializing 2D Movement")

	movementTrove:Clean()

	MovementController.CurrentMovementMode:Set(MovementModes.Moving2D)
	MovementController.MovementPlaneOrigin:Set(planeOrigin)
	MovementController.MovmentPlaneNormal:Set(planeNormal)

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
	local swimSpeed = 50
	local verticalSpeed = 50
	local momentumFactor = 2 -- Lower = driftier/slippery, Higher = snappier
	local entryDampening = 0.2 -- How much momentum is kept when entering water (0 to 1)
	local turnResponsiveness = 200 -- Controls how fast the character turns

	MovementController.SwimSpeed:Observe(function(newSwimSpeed)
		swimSpeed = newSwimSpeed
		verticalSpeed = newSwimSpeed
	end)

	-- Changed from Vector3 velocity to scalar speed to enforce "face-forward" movement
	local currentForwardSpeed = 0
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

	-- 4. Setup Plane Lock (Restricts depth movement)
	local planeLockAttachment = Instance.new("Attachment")
	planeLockAttachment.Name = "PlaneLockAttachment"
	planeLockAttachment.Parent = rootPart
	movementTrove:Add(planeLockAttachment)

	local planeConstraint = Instance.new("LinearVelocity")
	planeConstraint.Name = "PlaneConstraint"
	planeConstraint.Attachment0 = planeLockAttachment
	planeConstraint.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	planeConstraint.MaxAxesForce = Vector3.new(0, 0, 1000000) -- Lock Z axis only (relative to attachment)
	planeConstraint.VectorVelocity = Vector3.zero
	planeConstraint.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	planeConstraint.Parent = rootPart
	movementTrove:Add(planeConstraint)

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

			-- Capture and dampen entrance momentum
			-- We project the current velocity onto the look vector to keep forward momentum
			if rootPart then
				local currentVel = rootPart.AssemblyLinearVelocity
				local forwardDot = currentVel:Dot(rootPart.CFrame.LookVector)
				currentForwardSpeed = forwardDot * entryDampening
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
		-- Update Plane Lock Orientation
		-- We orient the attachment so its Z-axis (LookVector) points along the plane normal.
		-- This ensures the planeConstraint (which locks Z) restricts movement perpendicular to the plane.
		planeLockAttachment.WorldCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + planeNormal)

		if not isInWater then
			linearVelocity.MaxForce = 0
			alignOrientation.Enabled = false
			currentForwardSpeed = 0
			return
		end

		linearVelocity.MaxForce = 100000
		alignOrientation.Enabled = true

		local moveDir = humanoid.MoveDirection
		local targetDir = Vector3.zero
		local targetSpeed = 0

		-- Remap Inputs for 2D Swimming
		if moveDir.Magnitude > 0.01 then
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
				targetSpeed = swimSpeed
			end
		end

		-- Update Rotation: Face movement direction, keeping alignment with plane
		if targetDir.Magnitude > 0.01 then
			-- We want the character to look in the direction of movement.
			-- We want the character's 'Right' vector to align with the planeNormal (standard 2D orientation).
			local look = targetDir
			local right = planeNormal

			-- Calculate Up vector orthogonal to right and look
			local up = right:Cross(look).Unit

			-- Recalculate Right to ensure strict orthogonality (Cross product order matters for coordinate system)
			local rightOrtho = look:Cross(up).Unit

			-- Construct CFrame from Right, Up, and Back (-Look) vectors
			local targetCFrame = CFrame.fromMatrix(rootPart.Position, rightOrtho, up, -look)
			alignOrientation.CFrame = targetCFrame
		end

		-- Update Velocity: Always move along character's current forward facing
		-- Lerp scalar speed
		currentForwardSpeed = currentForwardSpeed
			+ (targetSpeed - currentForwardSpeed) * math.clamp(dt * momentumFactor, 0, 1)

		-- Apply along LookVector
		linearVelocity.VectorVelocity = rootPart.CFrame.LookVector * currentForwardSpeed
	end)

	movementTrove:Add(updateConnection)

	movementTrove:Add(function()
		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
		end
	end)
end
return MovementController
