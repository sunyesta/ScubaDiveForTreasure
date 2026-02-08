local ComponentBase = require(script.Parent.ComponentBase)
local MathUtils = require(script.Parent.Parent.Utils.MathUtils)

-- [AIM] Composer: Rotates the camera to look at a target
local Composer = setmetatable({}, ComponentBase)
Composer.__index = Composer

function Composer.new(lookAtOffset, damping)
	local self = setmetatable(ComponentBase.new(), Composer)
	self.LookAtOffset = lookAtOffset or Vector3.new(0, 0, 0)
	self.Damping = damping or 0.5
	self.CurrentRotation = nil
	return self
end

function Composer:Mutate(vcam, state, dt)
	local target = vcam.LookAt
	if not target then
		-- If no lookat, just use the position's implicit rotation or keep identity
		return
	end

	local targetPos = MathUtils.GetTargetPosition(target)
	if not targetPos then
		return
	end

	targetPos = targetPos + self.LookAtOffset

	local camPos = state.Position
	local lookDir = (targetPos - camPos).Unit

	-- Avoid looking straight up/down singularity
	if math.abs(lookDir.Y) > 0.99 then
		lookDir = Vector3.new(lookDir.X, 0.99 * math.sign(lookDir.Y), lookDir.Z).Unit
	end

	local targetRotation = CFrame.lookAt(Vector3.zero, lookDir)

	if not self.CurrentRotation then
		self.CurrentRotation = targetRotation
	end

	self.CurrentRotation = self.CurrentRotation:Lerp(targetRotation, 1 - math.exp(-dt / math.max(0.001, self.Damping)))
	state.Rotation = self.CurrentRotation
end

return Composer
