-------------------------------------------------------------------------------
-- MATH UTILITIES
-------------------------------------------------------------------------------
local MathUtils = {}

function MathUtils.Lerp(a, b, t)
	return a + (b - a) * t
end

function MathUtils.Damp(source, target, smoothing, dt)
	if smoothing <= 0 then
		return target
	end
	return source:Lerp(target, 1 - math.exp(-dt / smoothing))
end

function MathUtils.DampFloat(source, target, smoothing, dt)
	if smoothing <= 0 then
		return target
	end
	return source + (target - source) * (1 - math.exp(-dt / smoothing))
end

function MathUtils.GetTargetPosition(target)
	if typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			return target.Position
		elseif target:IsA("Model") then
			return target:GetPivot().Position
		end
	elseif typeof(target) == "CFrame" then
		return target.Position
	elseif typeof(target) == "Vector3" then
		return target
	end
	return nil
end
return MathUtils
