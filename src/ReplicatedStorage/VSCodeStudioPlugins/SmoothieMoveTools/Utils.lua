local Utils = {}

function Utils.LookAtWithoutUp(currentCFrame, targetPoint)
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

function Utils.GetRotationBetweenVectors(v1, v2, normal)
	local function getSignedAngleBetweenVectors(vectorA, vectorB, planeNormal)
		-- Normalize the input vectors
		local normalizedA = vectorA.Unit
		local normalizedB = vectorB.Unit

		-- Calculate the dot product to get the cosine of the angle
		local dotProduct = normalizedA:Dot(normalizedB)

		-- Calculate the unsigned angle using acos
		local angle = math.acos(math.clamp(dotProduct, -1, 1))

		-- Calculate the cross product to get the normal of the plane formed by vectorA and vectorB
		local crossProductAB = vectorA:Cross(vectorB)

		-- Check the dot product between the cross product and the original plane normal
		if crossProductAB:Dot(planeNormal) < 0 then -- Or > 0, depending on your desired sign convention
			angle = -angle
		end

		return angle
	end

	local angle = getSignedAngleBetweenVectors(v1, v2, normal)

	return CFrame.fromAxisAngle(normal, angle)
end

function Utils.ToDict(list)
	local newList = {}

	for _, item in pairs(list) do
		newList[item] = true
	end
	return newList
end

-- includeSelf defaults to true
function Utils.FindAncestor(instance, callback, includeSelf)
	includeSelf = if includeSelf == nil then true else includeSelf

	local ancestor = instance
	if ancestor == nil then
		return nil
	end

	if not includeSelf then
		ancestor = ancestor.Parent
	end

	while true do
		if not ancestor then
			break
		end

		if callback(ancestor) then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

function Utils.YLookAlong(at: Vector3, direction: Vector3, xDirection: Vector3?)
	return CFrame.lookAlong(at, direction) * CFrame.fromEulerAnglesXYZ(math.rad(-90), 0, 0)
end

return Utils
