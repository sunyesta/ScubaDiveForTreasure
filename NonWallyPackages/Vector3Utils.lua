local Vector3Utils = {}

-- UTILS

function Vector3Utils.Map(vector, callback)
	return Vector3.new(callback(vector.X), callback(vector.Y), callback(vector.Z))
end

function Vector3Utils.ToObjectSpace(cframe, vector)
	local relativeVector = vector - cframe.Position
	local localVector = cframe.Rotation:Inverse() * relativeVector
	return localVector
end

function Vector3Utils.ToWorldSpace(cframe, localVector)
	local worldVector = cframe * localVector
	return worldVector
end

function Vector3Utils.ScaleToPivot(pivotPos, pos, scaleFactor)
	return Vector3.new(
		(pivotPos.X + scaleFactor * (pos.X - pivotPos.X)),
		(pivotPos.Y + scaleFactor * (pos.Y - pivotPos.Y)),
		(pivotPos.Z + scaleFactor * (pos.Z - pivotPos.Z))
	)
end

function Vector3Utils.RoundDirectionToNearestAxis(direction)
	local absX, absY, absZ = math.abs(direction.X), math.abs(direction.Y), math.abs(direction.Z)

	if absX > absY and absX > absZ then
		return Vector3.new(math.sign(direction.X), 0, 0)
	elseif absY > absX and absY > absZ then
		return Vector3.new(0, math.sign(direction.Y), 0)
	else
		return Vector3.new(0, 0, math.sign(direction.Z))
	end
end

-- PROJECTION

function Vector3Utils.Project(vectorToProject, ontoVector)
	local ontoVectorUnit = ontoVector.Unit -- Normalize the "onto" vector

	-- Calculate the projection using the dot product
	local projection = ontoVectorUnit * vectorToProject:Dot(ontoVectorUnit)

	return projection
end

function Vector3Utils.ProjectOnPlane(vector: Vector3, planeNormal: Vector3)
	-- Normalize the plane normal to ensure it's a unit vector
	local normalizedNormal = planeNormal.Unit

	-- Calculate the dot product of the vector and the normalized normal
	local dotProduct = vector:Dot(normalizedNormal)

	-- Calculate the component of the vector that is parallel to the normal
	local parallelComponent = normalizedNormal * dotProduct

	-- Subtract the parallel component from the original vector to get the projection
	local projection = vector - parallelComponent

	return projection
end

-- INTERSECTION

function Vector3Utils.LineToPlaneIntersection(origin, direction, planeOrigin, planeNormal)
	local diff = origin - planeOrigin
	local prod1 = diff:Dot(planeNormal)
	local prod2 = direction:Dot(planeNormal)
	local prod3 = prod1 / prod2
	return origin - (direction * prod3)
end

function Vector3Utils.GetIntersectionBetweenLines(pt1, dir1, pt2, dir2)
	-- Ensure direction vectors are normalized (optional but good practice)
	dir1 = dir1.Unit
	dir2 = dir2.Unit

	-- Calculate the cross product of the direction vectors
	local crossDir = dir1:Cross(dir2)

	-- If the cross product is close to zero, the lines are parallel or collinear
	if crossDir.Magnitude < 1e-6 then
		return nil -- Lines are parallel or collinear, no unique intersection point
	end

	-- Vector from pt1 to pt2
	local w = pt1 - pt2

	-- Calculate the parameters t and u for the intersection points on each line
	local denominator = crossDir:Dot(crossDir)
	local t = (w:Cross(dir2)):Dot(crossDir) / denominator
	local u = (w:Cross(dir1)):Dot(crossDir) / denominator

	-- Calculate the intersection points on each line
	local intersection1 = pt1 + t * dir1
	local intersection2 = pt2 + u * dir2

	-- Due to floating-point inaccuracies, we check if the calculated intersection points are very close
	if (intersection1 - intersection2).Magnitude < 1e-6 then
		return intersection1 -- Or intersection2, they should be the same
	else
		return nil -- Lines are skew and do not intersect
	end
end

function Vector3Utils.GetLineAndSphereIntersections(
	lineOrigin: Vector3,
	lineDirection: Vector3,
	sphereOrigin: Vector3,
	sphereRadius: number
)
	-- Normalize the line direction to simplify calculations.
	-- This isn't strictly necessary but is good practice.
	local dir = lineDirection.Unit

	-- Calculate the vector from the sphere's origin to the line's origin.
	local toLineOrigin = lineOrigin - sphereOrigin

	-- Calculate the coefficients for the quadratic equation at^2 + bt + c = 0.
	-- a = dir · dir (which is 1 since dir is a unit vector)
	-- b = 2 * (dir · toLineOrigin)
	-- c = toLineOrigin · toLineOrigin - sphereRadius^2
	local a = dir:Dot(dir)
	local b = 2 * (dir:Dot(toLineOrigin))
	local c = toLineOrigin:Dot(toLineOrigin) - sphereRadius ^ 2

	-- Calculate the discriminant.
	local discriminant = b ^ 2 - 4 * a * c

	-- Check for the number of solutions based on the discriminant.
	local intersections = {}

	if discriminant >= 0 then
		local sqrtDiscriminant = math.sqrt(discriminant)

		-- Calculate the two possible values for t.
		local t1 = (-b - sqrtDiscriminant) / (2 * a)
		local t2 = (-b + sqrtDiscriminant) / (2 * a)

		-- Add the intersection points to the table.
		intersections[#intersections + 1] = lineOrigin + dir * t1

		-- If t1 and t2 are different, add the second intersection point.
		-- This accounts for the tangent case where t1 == t2.
		if t1 ~= t2 then
			intersections[#intersections + 1] = lineOrigin + dir * t2
		end
	end

	return intersections
end

-- CLOSEST POINT

function Vector3Utils.GetClosestPointOnLine(point, linePoint, lineDirection)
	-- Vector from a point on the line to the given point.
	local pointToLinePoint = point - linePoint

	-- Project the pointToLinePoint vector onto the line's direction vector.
	-- The scalar projection gives the distance along the line from linePoint
	-- to the closest point.
	local projectionScalar = pointToLinePoint:Dot(lineDirection)

	-- The closest point is then found by starting at linePoint and moving
	-- along the line's direction by the projection scalar.
	local closestPoint = linePoint + (lineDirection * projectionScalar)

	return closestPoint
end

function Vector3Utils.GetClosestPointOnLineFromLine(pt1, dir1, pt2, dir2)
	-- Ensure direction vectors are normalized (important for calculations)
	dir1 = dir1.Unit
	dir2 = dir2.Unit

	-- Vector connecting a point on each line
	local w0 = pt1 - pt2

	local a = dir1:Dot(dir1) -- Always 1 since dir1 is normalized
	local b = dir1:Dot(dir2)
	local c = dir2:Dot(dir2) -- Always 1 since dir2 is normalized
	local d = dir1:Dot(w0)
	local e = dir2:Dot(w0)

	local det = a * c - b * b

	-- If det is close to zero, the lines are nearly parallel
	if math.abs(det) < 1e-6 then
		-- Handle nearly parallel case: project pt2 onto the first line
		local t = w0:Dot(dir1)
		return pt1 - t * dir1
	else
		-- Calculate the parameter t for the closest point on the first line
		local t = (b * e - c * d) / det

		-- The closest point on the first line
		local closestPointOnLine1 = pt1 + t * dir1
		return closestPointOnLine1
	end
end

function Vector3Utils.ClosestPointOnSphere(point: Vector3, sphereOrigin: Vector3, sphereSize)
	local direction = point - sphereOrigin
	local distance = direction.Magnitude
	if distance == 0 then
		return sphereOrigin + Vector3.new(sphereSize, 0, 0) -- Return a point on the sphere if the point is at the center
	end
	local normalizedDirection = direction.Unit
	local closestPoint = sphereOrigin + (normalizedDirection * sphereSize)
	return closestPoint
end

function Vector3Utils.ClosestPointsOnSphereToLine(origin, direction, sphereOrigin, sphereSize)
	local r = sphereSize
	local o = sphereOrigin
	local p = origin
	local d = direction.Unit

	local a = d:Dot(d)
	local b = 2 * d:Dot(p - o)
	local c = (p - o):Dot(p - o) - r ^ 2

	local discriminant = b ^ 2 - 4 * a * c

	if discriminant < 0 then
		-- No intersection
		local t = (o - p):Dot(d)
		local closestPointOnLine = p + d * t
		local v = closestPointOnLine - o
		return { o + v.Unit * r }
	elseif discriminant == 0 then
		-- Tangent intersection
		local t = -b / (2 * a)
		local intersectionPoint = p + d * t
		return { intersectionPoint }
	else
		-- Two intersections
		local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
		local t2 = (-b - math.sqrt(discriminant)) / (2 * a)
		local intersectionPoint1 = p + d * t1
		local intersectionPoint2 = p + d * t2
		return { intersectionPoint1, intersectionPoint2 }
	end
end

-- Rotation

function Vector3Utils.GetRotationBetweenVectors(v1, v2, normal)
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

function Vector3Utils.GetRotationAroundNormal(normal, vector, zeroRotationVector)
	local normalizedVector = vector.Unit
	local normalizedNormal = normal.Unit
	local normalizedZeroRotationVector = zeroRotationVector.Unit

	-- Project the vectors onto the plane perpendicular to the normal
	local projectedVector = normalizedVector - normalizedNormal * normalizedVector:Dot(normalizedNormal)
	local projectedZeroRotationVector = normalizedZeroRotationVector
		- normalizedNormal * normalizedZeroRotationVector:Dot(normalizedNormal)

	-- Normalize the projected vectors
	local normalizedProjectedVector = projectedVector.Unit
	local normalizedProjectedZeroRotationVector = projectedZeroRotationVector.Unit

	-- Calculate the angle between the projected vectors
	local dotProduct = math.clamp(normalizedProjectedZeroRotationVector:Dot(normalizedProjectedVector), -1, 1)
	local angle = math.acos(dotProduct)

	-- Determine the direction of rotation using the cross product
	local crossProduct = normalizedProjectedZeroRotationVector:Cross(normalizedProjectedVector)
	if normalizedNormal:Dot(crossProduct) < 0 then
		angle = -angle
	end

	return angle
end

function Vector3Utils.AngularDistance(vector1, vector2)
	local normalizedVector1 = vector1.Unit
	local normalizedVector2 = vector2.Unit
	local dotProduct = math.clamp(normalizedVector1:Dot(normalizedVector2), -1, 1)
	return math.acos(dotProduct)
end

return Vector3Utils
