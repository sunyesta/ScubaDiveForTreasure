local Vector3Utils = {}

function Vector3Utils.LineToPlaneIntersection(origin, direction, planeOrigin, planeNormal)
	local diff = origin - planeOrigin
	local prod1 = diff:Dot(planeNormal)
	local prod2 = direction:Dot(planeNormal)
	local prod3 = prod1 / prod2
	return origin - (direction * prod3)
end

function Vector3Utils.ClosestPointFromPointToLine(point, lineOrigin, lineDirection)
	-- Ensure the line direction is a unit vector (normalized)
	local direction = lineDirection.Unit

	-- Vector from the line origin to the point
	local v = point - lineOrigin

	-- Project the vector onto the line direction to find the scalar projection
	local projection = v:Dot(direction)

	-- The closest point on the line is found by starting at the line origin
	-- and moving along the line direction by the calculated projection distance.
	local closestPoint = lineOrigin + direction * projection

	return closestPoint
end

return Vector3Utils
