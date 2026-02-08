local RunService = game:GetService("RunService")
local UpdateNetOwner: RemoteFunction

-- instances
if RunService:IsServer() then
	UpdateNetOwner = Instance.new("RemoteEvent")
	UpdateNetOwner.Name = "UpdateNetOwner"
	UpdateNetOwner.Parent = script
end

local BasePartUtils = {}

function BasePartUtils.ScaleTo(part, targetSize, pivotPoint)
	-- Apply the new size and position.
	part.Size = targetSize
	part.Position = BasePartUtils.GetPositionAfterScaleTo(part, targetSize, pivotPoint)
end

function BasePartUtils.GetPositionAfterScaleTo(part, targetSize, pivotPoint)
	-- part: The part to scale.
	-- targetSize: The desired new size (Vector3).
	-- pivotPoint: The point around which to scale (Vector3).

	local originalSize = part.Size
	local originalPosition = part.Position

	-- Calculate the offset from the original center to the pivot point.
	local offset = originalPosition - pivotPoint

	-- Calculate the new position based on the target size and offset.
	local sizeRatio = targetSize / originalSize
	local newOffset = offset * sizeRatio
	local newPosition = pivotPoint + newOffset

	return newPosition
end

local ownedParts = {}
function BasePartUtils.IsNetworkOwner(part)
	return if ownedParts[part] then true else false
end

local lockedOwnershipParts = {}
function BasePartUtils.SetNetworkOwner(part: BasePart, player: Player)
	assert(RunService:IsServer(), "Server only")

	if lockedOwnershipParts[part] == player then
		return
	end

	local lastPlayer = lockedOwnershipParts[part]

	part:SetNetworkOwner(player)
	lockedOwnershipParts[part] = player

	if player then
		UpdateNetOwner:FireClient(player, part, true)
	end

	if lastPlayer then
		UpdateNetOwner:FireClient(lastPlayer, part, false)
	end
end

function BasePartUtils.SetNetworkOwnershipAuto(part)
	assert(RunService:IsServer(), "Server only")

	local lastPlayer = lockedOwnershipParts[part]

	part:SetNetworkOwnershipAuto()
	lockedOwnershipParts[part] = nil

	if lastPlayer then
		UpdateNetOwner:FireClient(lastPlayer, part, false)
	end
end

function BasePartUtils.IsInsideBounds(
	partExtentsCFrame,
	partExtentsSize,
	boundsPartExtentsCFrame,
	boundsPartExtentsSize
)
	local isInside = true
	local buildBoxInverseCFrame = boundsPartExtentsCFrame:Inverse()

	-- We'll check the 8 corners of the model's bounding box
	local halfModelSize = partExtentsSize / 2
	local modelCorners = {
		partExtentsCFrame * CFrame.new(halfModelSize.X, halfModelSize.Y, halfModelSize.Z),
		partExtentsCFrame * CFrame.new(-halfModelSize.X, halfModelSize.Y, halfModelSize.Z),
		partExtentsCFrame * CFrame.new(halfModelSize.X, -halfModelSize.Y, halfModelSize.Z),
		partExtentsCFrame * CFrame.new(halfModelSize.X, halfModelSize.Y, -halfModelSize.Z),
		partExtentsCFrame * CFrame.new(-halfModelSize.X, -halfModelSize.Y, halfModelSize.Z),
		partExtentsCFrame * CFrame.new(halfModelSize.X, -halfModelSize.Y, -halfModelSize.Z),
		partExtentsCFrame * CFrame.new(-halfModelSize.X, halfModelSize.Y, -halfModelSize.Z),
		partExtentsCFrame * CFrame.new(-halfModelSize.X, -halfModelSize.Y, -halfModelSize.Z),
	}

	local halfBuildSize = boundsPartExtentsSize / 2

	for _, cornerCFrame in ipairs(modelCorners) do
		local transformedCorner = buildBoxInverseCFrame * cornerCFrame
		local p = transformedCorner.Position

		if math.abs(p.X) > halfBuildSize.X or math.abs(p.Y) > halfBuildSize.Y or math.abs(p.Z) > halfBuildSize.Z then
			isInside = false
			break
		end
	end

	return isInside
end

if RunService:IsClient() then
	task.spawn(function()
		UpdateNetOwner = script:WaitForChild("UpdateNetOwner")

		UpdateNetOwner.OnClientEvent:Connect(function(part, isOwner)
			if isOwner then
				ownedParts[part] = true
			else
				ownedParts[part] = nil
			end
		end)
	end)
end

return BasePartUtils
