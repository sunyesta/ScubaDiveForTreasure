local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local MathUtils = {}

function MathUtils.Lerp(start, goal, alpha)
	return start + (goal - start) * alpha
end

function MathUtils.FuzzyEq(num1, num2, alpha)
	alpha = alpha or 0.01
	return math.abs(num1 - num2) <= alpha
end

function MathUtils.ToRad(...)
	local vals = { ... }
	return unpack(TableUtil.Map(vals, function(val)
		return math.rad((360 + val))
	end))
end

function MathUtils.ToDeg(...)
	local vals = { ... }
	return unpack(TableUtil.Map(vals, function(val)
		return math.deg(val)
	end))
end

-- vals: {number}
-- func(val: number) -> number
function MathUtils.ApplyFunc(vals, func)
	return unpack(TableUtil.Map(vals, function(val)
		return func(val)
	end))
end

function MathUtils.ApplyToVector3(vec, func)
	return Vector3.new(func(vec.X), func(vec.Y), func(vec.Z))
end

function MathUtils.Clamp(x, min, max)
	if min > max then
		local temp = min
		min = max
		max = temp
	end

	return math.clamp(x, min, max)
end

function MathUtils.Vector3(x)
	return Vector3.new(x, x, x)
end

function MathUtils.Round(num, numPlaces)
	local scale = (10 ^ numPlaces)
	return math.round(num * scale) / scale
end

function MathUtils.RollDice(probability: number, resolution: number?, seed: number?)
	if seed then -- set the seed
		math.randomseed(seed)
	end
	resolution = resolution or 1000
	local result = math.random(resolution) / resolution < probability

	if seed then -- make the seed random again
		math.randomseed(tick())
	end

	return result
end

function MathUtils.GetRandomFromList(list)
	return list[math.random(#list)]
end

function MathUtils.GetRandomSeed()
	local MIN_SEED_RANGE: number = -2147483648
	local MAX_SEED_RANGE: number = 2147483647

	local seed = math.random(500)
	return seed
end

return MathUtils
