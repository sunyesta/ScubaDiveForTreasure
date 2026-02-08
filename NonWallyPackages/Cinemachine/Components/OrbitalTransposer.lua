local UserInputService = game:GetService("UserInputService")
local ComponentBase = require(script.Parent.ComponentBase)
local MathUtils = require(script.Parent.Parent.Utils.MathUtils)
-- [BODY] OrbitalTransposer: FreeLook style orbit
local OrbitalTransposer = setmetatable({}, ComponentBase)
OrbitalTransposer.__index = OrbitalTransposer

function OrbitalTransposer.new(radius, height, damping)
	local self = setmetatable(ComponentBase.new(), OrbitalTransposer)
	self.Radius = radius or 10
	self.Height = height or 5
	self.Damping = damping or 0.1
	self.XAxis = { Value = 0, Speed = 200 } -- Degrees
	self.YAxis = { Value = 0.5, Speed = 2 } -- 0 to 1
	self.CurrentPos = nil
	return self
end

function OrbitalTransposer:UpdateInput(dt)
	-- Simple Input Handling (Customize this for Mobile/Console)
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local delta = UserInputService:GetMouseDelta()
		self.XAxis.Value = self.XAxis.Value - (delta.X * 0.5)
		self.YAxis.Value = math.clamp(self.YAxis.Value + (delta.Y * 0.005), 0.01, 0.99)
	end
end

function OrbitalTransposer:Mutate(vcam, state, dt)
	local target = vcam.Follow
	if not target then
		return
	end
	local targetPos = MathUtils.GetTargetPosition(target)

	self:UpdateInput(dt)

	local theta = math.rad(self.XAxis.Value)

	-- Calculate orbit position based on spherical coords driven by axes
	local r = self.Radius * (2 - self.YAxis.Value) -- Simple radius scaler based on Y
	local h = self.Height * (self.YAxis.Value * 2 - 1) * 5 -- Height scaler

	local offset = Vector3.new(math.sin(theta) * r, h, math.cos(theta) * r)
	local desiredPos = targetPos + offset

	if not self.CurrentPos then
		self.CurrentPos = desiredPos
	end

	self.CurrentPos = self.CurrentPos:Lerp(desiredPos, 1 - math.exp(-dt / math.max(0.001, self.Damping)))
	state.Position = self.CurrentPos
end

return OrbitalTransposer
