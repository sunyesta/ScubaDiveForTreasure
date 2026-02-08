local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RayVisualizer = require(ReplicatedStorage.NonWallyPackages.RayVisualizer)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)

local RaycastBurst = {}

local GOLDEN_RATIO = (1 + math.sqrt(5)) / 2 -- 1.68

function RaycastBurst.fromDirections(origin, directions, raycastParams, viewSecs)
	local results = {}
	for _, direction in pairs(directions) do
		local result = workspace:Raycast(origin, direction, raycastParams) -- Raycast with slight buffer to account for part size

		if viewSecs ~= nil and viewSecs > 0 then
			RayVisualizer.newFromRaycast(origin, direction, result, viewSecs)
		end

		table.insert(results, result)
	end

	return results
end

function RaycastBurst.fromGoldenRatio(origin, radius, rayCount, raycastParams, viewSecs)
	local function calculateDirection(i, rayCount, ratio)
		-- https://extremelearning.com.au/how-to-evenly-distribute-points-on-a-sphere-more-effectively-than-the-canonical-fibonacci-lattice/
		ratio = ratio or GOLDEN_RATIO

		local theta = math.pi * 2 * i / GOLDEN_RATIO -- Scale by phi for even distribution

		local phi = math.acos(1 - 2 * i / rayCount)
		local x = math.cos(theta) * math.sin(phi)
		local y = math.sin(theta) * math.sin(phi)
		local z = math.cos(phi)
		return Vector3.new(x, y, z).Unit
	end

	assert(rayCount >= 6, "at least 6 rays minimum")

	local directions = {
		Vector3.new(-1, 0, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0, -1, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, -1),
		Vector3.new(0, 0, 1),
	}
	for i = 1, rayCount - 6 do
		table.insert(directions, calculateDirection(i, rayCount, GOLDEN_RATIO) * radius)
	end

	return RaycastBurst.fromDirections(origin, directions, raycastParams, viewSecs)
end

function RaycastBurst.fromPlaneBurst(origin, radius, rayCount, planeNormal, raycastParams, viewSecs)
	local directions = {}

	local angleSize = 2 * math.pi / rayCount
	for i = 0, rayCount do
		local x = math.cos(angleSize * i)
		local y = math.sin(angleSize * i)

		table.insert(directions, Vector3.new(x, y, 0))
	end

	directions = TableUtil.Map(directions, function(direction)
		return (CFrame.lookAlong(Vector3.new(0, 0, 0), planeNormal) * CFrame.lookAlong(Vector3.new(0, 0, 0), direction)).LookVector.Unit
			* radius
	end)

	return RaycastBurst.fromDirections(origin, directions, raycastParams, viewSecs)
end

function RaycastBurst.GetClosest(results, position)
	return TableUtil2.Best(results, function(val1, val2)
		return (val1.Position - position).Magnitude < (val2.Position - position).Magnitude
	end)
end
return RaycastBurst
