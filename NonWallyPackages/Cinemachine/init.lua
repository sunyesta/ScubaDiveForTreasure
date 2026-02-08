local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

local Transposer = require(script.Components.Transposer)
local Composer = require(script.Components.Composer)
local OrbitalTransposer = require(script.Components.OrbitalTransposer)
local Trackball = require(script.Components.Trackball)
local RobloxControlCamera = require(script.Components.RobloxControlCamera)
local Brain = require(script.Core.Brain)
local VirtualCamera = require(script.Core.VirtualCamera)

-- Cinemachine for Roblox
-- A port of the core concepts of Unity's Cinemachine system.
-- Handles Camera State, Blending, Priorities, and Pipelines (Body/Aim).

local Cinemachine = {}
Cinemachine.__index = Cinemachine

-------------------------------------------------------------------------------
-- MODULE EXPORTS
-------------------------------------------------------------------------------
Cinemachine.Brain = Brain.new()
Cinemachine.VirtualCamera = VirtualCamera
Cinemachine.Components = {
	Transposer = Transposer,
	Composer = Composer,
	OrbitalTransposer = OrbitalTransposer,
	Trackball = Trackball,
	RobloxControlCamera = RobloxControlCamera,
}

Cinemachine._trove = Trove.new()

-- Auto-start the brain loop
Cinemachine._trove:BindToRenderStep("CinemachineBrainUpdate", Enum.RenderPriority.Camera.Value + 1, function(dt)
	Cinemachine.Brain:Update(dt)
end)

function Cinemachine:Destroy()
	self._trove:Destroy()
end

return Cinemachine
