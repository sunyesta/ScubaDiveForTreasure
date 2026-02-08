local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local RayVisualizer = require(ReplicatedStorage.NonWallyPackages.RayVisualizer)
local Workspace = game:GetService("Workspace")

local RaycastUtils = {}

function RaycastUtils.AllHits(rayOrigin: Vector3, rayDirection: Vector3, raycastParams: RaycastParams)
	local origOrigin = rayOrigin

	local results = {}

	while true do
		local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if result then
			table.insert(
				results,
				table.freeze({
					Distance = (origOrigin - result.Position).Magnitude,
					Instance = result.Instance,
					Material = result.Material,
					Position = result.Position,
					Normal = result.Normal,
				})
			)

			rayOrigin = result.Position + (rayDirection.Unit * 0.1)
			rayDirection -= rayDirection.Unit * result.Distance
		else
			break
		end
	end

	return results
end

function RaycastUtils.LastHit(rayOrigin: Vector3, rayDirection: Vector3, raycastParams: RaycastParams)
	local results = RaycastUtils.AllHits(rayOrigin, rayDirection, raycastParams)

	return if #results > 0 then results[#results] else nil
end

function RaycastUtils.FindNextValidHit(rayOrigin: Vector3, rayDirection: Vector3, raycastParams: RaycastParams, isValid)
	while true do
		local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if result then
			if isValid(result) then
				return result
			else
				rayOrigin = result.Position + (rayDirection.Unit * 0.1)
				rayDirection -= rayDirection.Unit * result.Distance
			end
		else
			break
		end
	end

	return nil
end

function RaycastUtils.CopyRaycastParams(raycastParams: RaycastParams)
	local newRaycastParams = RaycastParams.new()

	newRaycastParams.FilterDescendantsInstances = raycastParams.FilterDescendantsInstances
	newRaycastParams.FilterType = raycastParams.FilterType
	newRaycastParams.IgnoreWater = raycastParams.IgnoreWater
	newRaycastParams.CollisionGroup = raycastParams.CollisionGroup
	newRaycastParams.RespectCanCollide = raycastParams.RespectCanCollide
	newRaycastParams.BruteForceAllSlow = raycastParams.BruteForceAllSlow

	return newRaycastParams
end

return RaycastUtils
