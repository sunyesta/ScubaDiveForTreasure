local MathUtils = require(script.Parent.Parent.Utils.MathUtils)
local Constants = require(script.Parent.Parent.Utils.Constants)
-- Constants

-------------------------------------------------------------------------------
-- CAMERA STATE
-------------------------------------------------------------------------------
local CameraState = {}
CameraState.__index = CameraState

function CameraState.new()
	return setmetatable({
		Position = Vector3.new(),
		Rotation = CFrame.new(), -- Rotation only CFrame usually
		FieldOfView = Constants.DEFAULT_FOV,
		Up = Vector3.yAxis,
	}, CameraState)
end

function CameraState.Lerp(stateA, stateB, t)
	local newState = CameraState.new()
	newState.Position = stateA.Position:Lerp(stateB.Position, t)

	-- Spherical interpolation for rotation
	local rotA = stateA.Rotation
	local rotB = stateB.Rotation
	newState.Rotation = rotA:Lerp(rotB, t)

	newState.FieldOfView = MathUtils.Lerp(stateA.FieldOfView, stateB.FieldOfView, t)
	newState.Up = stateA.Up:Lerp(stateB.Up, t).Unit
	return newState
end

return CameraState
