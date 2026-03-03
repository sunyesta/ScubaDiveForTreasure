local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cameras = require(ReplicatedStorage.Common.Modules.Cameras)
local WindShake = require(ReplicatedStorage.Packages.WindShake)

local WIND_DIRECTION = Vector3.new(1, 0, 0.3)
local WIND_SPEED = 5
local WIND_POWER = 1
local SHAKE_DISTANCE = 150

WindShake:SetDefaultSettings({
	WindSpeed = WIND_SPEED,
	WindDirection = WIND_DIRECTION,
	WindPower = WIND_POWER,
})
WindShake:Init({
	MatchWorkspaceWind = false,
})

return {}
