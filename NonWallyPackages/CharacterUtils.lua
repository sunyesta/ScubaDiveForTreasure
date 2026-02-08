local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Promise = require(ReplicatedStorage.Packages.Promise)
local PointVisualizer = require(ReplicatedStorage.NonWallyPackages.PointVisualizer)
local CharacterUtils = {}

function CharacterUtils.GetCharacterFromPart(part)
	if (not part) or not part.Parent then
		return
	end

	return InstanceUtils.FindAncestor(part, function(inst)
		return inst:IsA("Model") and inst:FindFirstChild("Humanoid")
	end)
end

function CharacterUtils.LockHumanoidState(humanoid, activeState)
	local trove = Trove.new()

	activeState = activeState or humanoid:GetState()

	for _, state in Enum.HumanoidStateType:GetEnumItems() do
		if state ~= activeState and state ~= Enum.HumanoidStateType.None then
			humanoid:SetStateEnabled(state, false)
		end
	end
	humanoid:ChangeState(activeState)

	trove:Add(function()
		for _, state in Enum.HumanoidStateType:GetEnumItems() do
			if state ~= activeState and state ~= Enum.HumanoidStateType.None then
				humanoid:SetStateEnabled(state, true)
			end
		end
	end)

	return trove
end

function CharacterUtils.UnlockAllHumanoidStates(humanoid)
	for _, state in Enum.HumanoidStateType:GetEnumItems() do
		if state ~= Enum.HumanoidStateType.None then
			humanoid:SetStateEnabled(state, true)
		end
	end
end

function CharacterUtils.GetCharacterLimbs(character)
	return {
		character.Head,
		character.LeftFoot,
		character.LeftHand,
		character.LeftLowerArm,
		character.LeftLowerLeg,
		character.LeftUpperArm,
		character.LeftUpperLeg,
		character.LowerTorso,
		character.RightFoot,
		character.RightHand,
		character.RightLowerArm,
		character.RightLowerLeg,
		character.RightUpperArm,
		character.RightUpperLeg,
		character.UpperTorso,
	}
end

local HideCharacterTroves = {}
function CharacterUtils.HideCharacter(character, collisionGroup)
	local playerParts = TableUtil.Filter(character:GetDescendants(), function(inst)
		return inst:IsA("BasePart")
	end)

	if HideCharacterTroves[character] then
		HideCharacterTroves[character]:Clean()
	else
		HideCharacterTroves[character] = Trove.new()
	end

	-- make parts transparent and non collideable
	for _, part in playerParts do
		local oldTransparency = part.Transparency
		local oldCanTouch, oldCanQuery = part.CanTouch, part.CanQuery
		local oldCollisionGroup = part.CollisionGroup

		part.Transparency = 1

		if collisionGroup then
			part.CollisionGroup = collisionGroup
			part.CanTouch, part.CanQuery = false, false
		end

		HideCharacterTroves[character]:Add(function()
			if part.Parent then
				part.Transparency = oldTransparency

				if collisionGroup then
					part.CollisionGroup = oldCollisionGroup
					part.CanTouch, part.CanQuery = oldCanTouch, oldCanQuery
				end
			end
		end)
	end

	HideCharacterTroves[character]:Add(function()
		HideCharacterTroves[character] = nil
	end)

	HideCharacterTroves[character]:AttachToInstance(character)

	return HideCharacterTroves[character]
end

function CharacterUtils.ShowCharacter(character)
	HideCharacterTroves[character]:Clean()
end

function CharacterUtils.WalkToPosition(character, pos, pathFind, costs, overrideCharacterRadius)
	assert(typeof(pos) == "Vector3", "Position must be a vector3")
	return Promise.new(function(resolve, reject)
		local extentsSize = character:GetExtentsSize()
		local pathParams = {
			AgentRadius = math.max(extentsSize.X + 1, extentsSize.Z + 1),
			AgentHeight = extentsSize.Y,
			AgentCanJump = true,
			Costs = costs,
		}

		local humanoid: Humanoid = character.Humanoid

		local function followPath()
			local pathTrove = Trove.new()
			local path = PathfindingService:CreatePath(pathParams)

			-- Compute the path
			local success, errorMessage = pcall(function()
				path:ComputeAsync(character:GetPivot().Position, pos)
			end)
			if (not success) or path.Status ~= Enum.PathStatus.Success then
				reject()
				print("FAILED")
				return
			end

			-- Get the path waypoints
			local waypoints = path:GetWaypoints()
			local nextWaypointIndex = 2 --(first waypoint is path start; skip it)

			-- print(#waypoints)
			-- print(waypoints[1].Position)
			for _, wp in waypoints do
				pathTrove:Add(PointVisualizer.new(wp.Position))
			end

			-- Detect if path becomes blocked
			pathTrove:Add(path.Blocked:Connect(function(blockedWaypointIndex)
				-- Check if the obstacle is further down the path
				if blockedWaypointIndex >= nextWaypointIndex then
					-- Stop detecting path blockage until path is re-computed
					pathTrove:Clean()
					followPath()
				end
			end))

			pathTrove:Add(humanoid.MoveToFinished:Connect(function(reached)
				if reached and nextWaypointIndex < #waypoints then
					-- Increase waypoint index and move to next waypoint
					nextWaypointIndex += 1

					print("MOVETO")
					humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
				else
					pathTrove:Clean()

					print("MOVETO")
					humanoid:MoveTo(character.HumanoidRootPart.Position)
					resolve()
				end
			end))

			print("MOVETO")
			humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
		end

		if pathFind then
			followPath()
		else
			local pathTrove = Trove.new()

			print("MOVETO")
			humanoid:MoveTo(pos)

			pathTrove:Add(humanoid.MoveToFinished:Connect(function(reached)
				pathTrove:Clean()
				resolve()
			end))
		end
	end)
end

return CharacterUtils
