local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MathUtils = require(ReplicatedStorage.NonWallyPackages.MathUtils)
local CFrameUtils = {}

function CFrameUtils.YLookAlong(at: Vector3, direction: Vector3, xDirection: Vector3?)
	return CFrame.lookAlong(at, direction) * CFrame.fromEulerAnglesXYZ(math.rad(-90), 0, 0)
end

function CFrameUtils.IsInFront(baseCFrame, position)
	local point1, point2 = (baseCFrame + baseCFrame.LookVector * -1), (baseCFrame + baseCFrame.LookVector)
	local behindMag, aheadMag = (point1.Position - position).Magnitude, (point2.Position - position).Magnitude
	return aheadMag <= behindMag
end

function CFrameUtils.ToEulerAnglesXZY(cframe)
	local m = { select(4, cframe:GetComponents()) }

	local x = math.atan2(m[8], m[5])
	local z = math.asin(-m[2])
	local y = math.atan2(m[3], m[1])

	return x, y, z
end

function CFrameUtils.ToEulerAnglesXYZ(cframe)
	-- alternatively:
	-- local m = {select(4, cframe:GetComponents())}

	-- local x = math.atan2(-m[6], m[9])
	-- local y = math.asin(m[3])
	-- local z = math.atan2(-m[2], m[1])

	-- return x, y, z

	return cframe:ToEulerAnglesXYZ()
end

function CFrameUtils.ToEulerAnglesYXZ(cframe)
	-- alternatively:
	-- local m = {select(4, cframe:GetComponents())}

	-- local y = math.atan2(m[3], m[9])
	-- local x = math.asin(-m[6])
	-- local z = math.atan2(m[4], m[5]);

	-- return x, y, z

	return cframe:ToEulerAnglesYXZ()
end

function CFrameUtils.ToEulerAnglesYZX(cframe)
	local m = { select(4, cframe:GetComponents()) }

	local y = math.atan2(-m[7], m[1])
	local z = math.asin(m[4])
	local x = math.atan2(-m[6], m[5])

	return x, y, z
end

function CFrameUtils.ToEulerAnglesZYX(cframe)
	local m = { select(4, cframe:GetComponents()) }

	local z = math.atan2(m[4], m[1])
	local y = math.asin(-m[7])
	local x = math.atan2(m[8], m[9])

	return x, y, z
end

function CFrameUtils.ToEulerAnglesZXY(cframe)
	local m = { select(4, cframe:GetComponents()) }

	local z = math.atan2(-m[2], m[5])
	local x = math.asin(m[8])
	local y = math.atan2(-m[7], m[9])

	return x, y, z
end

function CFrameUtils.FromEulerAnglesXZY(x, y, z)
	return CFrame.Angles(x, 0, 0) * CFrame.Angles(0, 0, z) * CFrame.Angles(0, y, 0)
end

function CFrameUtils.AlignUpWithNormal(cframe, normal)
	local position = cframe.Position

	normal = MathUtils.ApplyToVector3(normal, function(x)
		return MathUtils.Round(x, 3)
	end)

	if normal:FuzzyEq(Vector3.new(0, 1, 0), 0.05) then
		cframe = CFrame.new(position)
	else
		cframe = CFrame.lookAlong(position, normal, Vector3.new(0, 1, 0))
			* CFrame.fromEulerAnglesXYZ(math.rad(-90), 0, 0)
	end

	return cframe
end

function CFrameUtils.RotateYToPlaneIntersection(cframe, ray)
	local function rayToPlaneIntersection(origin, direction, planeOrigin, planeDirection)
		local diff = origin - planeOrigin
		local prod1 = diff:Dot(planeDirection)
		local prod2 = direction:Dot(planeDirection)
		local prod3 = prod1 / prod2
		return origin - (direction * prod3)
	end
	local intersection = rayToPlaneIntersection(ray.Origin, ray.Direction, cframe.Position, cframe.UpVector)
	return CFrame.lookAt(cframe.Position, intersection, cframe.UpVector)
end

function CFrameUtils.LookAtWithLockedUp(currentCFrame, targetPoint)
	local currentPosition = currentCFrame.Position
	local upVector = currentCFrame.UpVector
	local directionToTarget = (targetPoint - currentPosition)

	-- Project the direction to the target onto the plane perpendicular to the up vector
	local directionOnPlane = (directionToTarget - (directionToTarget:Dot(upVector) * upVector)).Unit

	-- If the target is directly above or below, avoid errors
	if directionOnPlane.Magnitude == 0 then
		return currentCFrame -- No rotation needed or well-defined
	end

	-- Create a new look vector
	local newLookVector = directionOnPlane

	-- The right vector is the cross product of the up and the new look
	local newRightVector = upVector:Cross(newLookVector).Unit

	-- Construct the new CFrame
	local newCFrame = CFrame.fromMatrix(currentPosition, newRightVector, upVector, newLookVector)
	return newCFrame
end

return CFrameUtils
