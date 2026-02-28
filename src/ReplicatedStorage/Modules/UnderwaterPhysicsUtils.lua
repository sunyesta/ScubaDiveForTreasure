--!strict
local UnderwaterPhysicsUtils = {}

--[[
	Applies a temporary LinearVelocity to a Character model to simulate a bounce.
	
	@param character The Character model to bounce.
	@param velocity The Vector3 directional velocity to apply.
	@param duration How long (in seconds) the force should remain active before cleanup.
]]
function UnderwaterPhysicsUtils.BounceObject(root: BasePart, velocity: Vector3, duration: number)
	-- 1. Create Physics Objects (Set properties before parenting for better performance)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BounceAttachment"

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "BounceVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = math.huge -- Apply infinite force to reach velocity instantly
	linearVelocity.VectorVelocity = velocity
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World

	-- Parent instances last
	attachment.Parent = root
	linearVelocity.Parent = root

	-- 2. Cleanup after the duration passes
	task.delay(duration, function()
		if linearVelocity then
			linearVelocity:Destroy()
		end
		if attachment then
			attachment:Destroy()
		end
	end)
end

return UnderwaterPhysicsUtils
