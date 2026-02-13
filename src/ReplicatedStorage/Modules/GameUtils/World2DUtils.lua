local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Assuming Trove is in Packages. Adjust path if necessary.
-- If you don't have Trove, you can use a simpler cleanup method,
-- but this follows your provided structure.
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local World2DUtils = {}

World2DUtils.DefaultPlaneNormal = Vector3.new(0, 0, -1)
World2DUtils.DefaultPlaneOrigin = workspace:WaitForChild("MAP"):WaitForChild("WaterPlane").Position

--[[
    Creates a constraint that locks the character's movement to a 2D plane defined by the normal.
    Snaps the character to the plane initially to prevent physics jitter.
    
    @param rootPart (BasePart) The HumanoidRootPart of the character
    @param planeOrigin (Vector3) A point on the plane (e.g., the center of the level)
    @param planeNormal (Vector3) The normal vector of the plane (e.g., Vector3.new(0, 0, 1))
    @return Trove object containing cleanup tasks
]]
function World2DUtils.ConstrainToPlane(rootPart: BasePart, planeOrigin: Vector3, planeNormal: Vector3)
	local trove = Trove.new()

	-- set default values if needed
	planeOrigin = planeOrigin or World2DUtils.DefaultPlaneOrigin
	planeNormal = planeNormal or World2DUtils.DefaultPlaneNormal

	-- Ensure the normal is a unit vector for correct math
	planeNormal = planeNormal.Unit

	-- 0. SNAP TO PLANE (The Teleport)
	-- We calculate the closest point on the plane to the rootPart.
	-- Formula: P_proj = P - ( (P - P_0) dot n ) * n
	local currentPos = rootPart.Position
	local vectorToPoint = currentPos - planeOrigin
	local distanceToPlane = vectorToPoint:Dot(planeNormal)
	local snappedPosition = currentPos - (planeNormal * distanceToPlane)

	-- Teleport the rootPart. We preserve the original rotation.
	rootPart.CFrame = CFrame.new(snappedPosition) * rootPart.CFrame.Rotation

	-- 1. Create Attachment (Required for LinearVelocity)
	local planeLockAttachment = Instance.new("Attachment")
	planeLockAttachment.Name = "PlaneLockAttachment"
	planeLockAttachment.Parent = rootPart
	trove:Add(planeLockAttachment)

	-- 2. Create LinearVelocity Constraint
	local planeConstraint = Instance.new("LinearVelocity")
	planeConstraint.Name = "PlaneConstraint"
	planeConstraint.Attachment0 = planeLockAttachment
	planeConstraint.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	planeConstraint.VectorVelocity = Vector3.zero
	planeConstraint.Parent = rootPart
	trove:Add(planeConstraint)

	-- 3. Check for Axis Alignment
	-- If the plane is perfectly aligned with World X, Y, or Z, we can use World space physics
	-- and avoid running a script every frame.
	local isX = math.abs(planeNormal.X) > 0.999
	local isY = math.abs(planeNormal.Y) > 0.999
	local isZ = math.abs(planeNormal.Z) > 0.999

	if isX or isY or isZ then
		-- OPTIMIZED: Plane is Axis-Aligned. Use World Space.
		planeConstraint.RelativeTo = Enum.ActuatorRelativeTo.World

		-- Lock the axis that matches the normal
		if isX then
			planeConstraint.MaxAxesForce = Vector3.new(1000000, 0, 0)
		elseif isY then
			planeConstraint.MaxAxesForce = Vector3.new(0, 1000000, 0)
		else -- isZ
			planeConstraint.MaxAxesForce = Vector3.new(0, 0, 1000000)
		end
	else
		-- STANDARD: Plane is arbitrary/diagonal.
		-- We must use Attachment Space and rotate the attachment to match the plane normal.
		planeConstraint.RelativeTo = Enum.ActuatorRelativeTo.Attachment0

		-- Lock Z axis (relative to attachment). Since we orient the attachment's Z
		-- to face the normal, this locks movement along the normal.
		planeConstraint.MaxAxesForce = Vector3.new(0, 0, 1000000)

		-- Orient attachment initially
		planeLockAttachment.WorldCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + planeNormal)

		-- We must continuously orient the attachment so its Z-axis (LookVector) aligns with the planeNormal.
		-- This ensures the LinearVelocity (which locks local Z) prevents movement off the plane.
		trove:Add(RunService.Stepped:Connect(function()
			if not rootPart or not rootPart.Parent then
				return
			end

			-- Update attachment orientation to face the normal
			planeLockAttachment.WorldCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + planeNormal)
		end))
	end

	return trove
end

return World2DUtils
