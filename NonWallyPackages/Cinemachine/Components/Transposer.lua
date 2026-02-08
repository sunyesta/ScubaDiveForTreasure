local ComponentBase = require(script.Parent.ComponentBase)
local MathUtils = require(script.Parent.Parent.Utils.MathUtils)

-- [BODY] Transposer: Moves the camera to follow a target with an offset and damping
local Transposer = setmetatable({}, ComponentBase)
Transposer.__index = Transposer

function Transposer.new(offset, damping)
	local self = setmetatable(ComponentBase.new(), Transposer)
	self.FollowOffset = offset or Vector3.new(0, 5, 10)
	self.Damping = damping or Vector3.new(0.5, 0.5, 0.5) -- XYZ damping
	self.PreviousTargetPosition = nil
	self.CurrentPosition = nil
	return self
end

function Transposer:Mutate(vcam, state, dt)
	local target = vcam.Follow
	if not target then
		return
	end

	local targetPos = MathUtils.GetTargetPosition(target)
	if not targetPos then
		return
	end

	-- Initialize if first frame
	if not self.CurrentPosition then
		self.CurrentPosition = targetPos + self.FollowOffset
		self.PreviousTargetPosition = targetPos
	end

	local desiredPos = targetPos + self.FollowOffset

	-- Apply Damping per axis
	local dampedX = MathUtils.DampFloat(self.CurrentPosition.X, desiredPos.X, self.Damping.X, dt)
	local dampedY = MathUtils.DampFloat(self.CurrentPosition.Y, desiredPos.Y, self.Damping.Y, dt)
	local dampedZ = MathUtils.DampFloat(self.CurrentPosition.Z, desiredPos.Z, self.Damping.Z, dt)

	self.CurrentPosition = Vector3.new(dampedX, dampedY, dampedZ)
	state.Position = self.CurrentPosition
end

return Transposer
