-- src: https://gist.github.com/EgoMoose/7a8f4d7b00ffe45abce8ade72b173284/

local quaternion = { __type = "quaternion" }
local quaternion_mt = { __index = quaternion }
local ref = setmetatable({}, { __mode = "k" })

local PI = math.pi
local abs = math.abs
local cos = math.cos
local sin = math.sin
local acos = math.acos
local sqrt = math.sqrt

function quaternion_mt.__mul(q0, q1)
	local w0, w1 = q0.w, q1.w
	local v0, v1 = ref[q0], ref[q1]
	local nw = w0 * w1 - v0:Dot(v1)
	local nv = v0 * w1 + v1 * w0 + v0:Cross(v1)
	return quaternion.new(nw, nv.x, nv.y, nv.z)
end

function quaternion_mt.__pow(q0, t)
	local axis, theta = q0:toAxisAngle()
	theta = theta * t * 0.5
	axis = sin(theta) * axis
	return quaternion.new(cos(theta), axis.x, axis.y, axis.z)
end

function quaternion_mt.__tostring(q0)
	local t = { q0.w, q0.x, q0.y, q0.z }
	return table.concat(t, ", ")
end

function quaternion.new(w, x, y, z)
	local self = {}

	self.w = w
	self.x = x
	self.y = y
	self.z = z

	self = setmetatable(self, quaternion_mt)
	ref[self] = Vector3.new(x, y, z)

	return self
end

function quaternion.fromCFrame(cf)
	local axis, theta = cf:toAxisAngle()
	theta = theta * 0.5
	axis = sin(theta) * axis
	return quaternion.new(cos(theta), axis.x, axis.y, axis.z)
end

function quaternion:inverse()
	local w = self.w
	local conjugate = w * w + ref[self]:Dot(ref[self])

	local nw = w / conjugate
	local nv = -ref[self] / conjugate

	return quaternion.new(nw, nv.x, nv.y, nv.z)
end

function quaternion:toAxisAngle()
	local axis = ref[self]
	local theta = acos(self.w) * 2

	-- if theta is equivalent to zero then pick a random axis
	if theta % (PI * 2) == 0 and axis:Dot(axis) == 0 then
		axis = Vector3.new(1, 0, 0)
	end

	return axis.unit, theta
end

function quaternion:slerp(self2, t)
	return ((self2 * self:inverse()) ^ t) * self
end

function quaternion:slerpClosest(self2, t)
	if self.w * self2.w + self.x * self2.x + self.y * self2.y + self.z * self2.z > 0 then
		-- choose self2
		return self:slerp(self2, t)
	else
		-- choose -self2
		self2 = quaternion.new(-self2.w, -self2.x, -self2.y, -self2.z)
		return self:slerp(self2, t)
	end
end

function quaternion:toCFrame()
	return CFrame.new(0, 0, 0, self.x, self.y, self.z, self.w)
end

return quaternion
