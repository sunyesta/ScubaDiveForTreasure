local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cinemachine = require(ReplicatedStorage.NonWallyPackages.Cinemachine)
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local GameEnums = require(ReplicatedStorage.Common.GameInfo.GameEnums)

local Player = Players.LocalPlayer

function PlayerCamera()
	local playerCamera = Cinemachine.VirtualCamera.new("PlayerCamera")
	playerCamera.Priority = GameEnums.CameraPriorities.PlayerCamera
	Cinemachine.Brain:RefreshPriority()

	-- The Body component (RobloxControlCamera) is what handles positioning and offsets
	playerCamera.Body = Cinemachine.Components.RobloxControlCamera.new({
		StartDistance = 15,
		MinDistance = 0,
		MaxDistance = 30,
		CollisionEnabled = true,
		MouseLock = false,
		RotatePlayerWithShiftlock = false,
	})

	Cinemachine.Brain:Register(playerCamera)

	PlayerUtils.ObserveCharacterAdded(Player, function(character)
		character:WaitForChild("Humanoid")
		playerCamera.Follow = character.Humanoid
		playerCamera.LookAt = character.Humanoid
	end)

	playerCamera.Body.RotatePlayerWithShiftlock = true

	return playerCamera
end
function PlayerCamera2D()
	local playerCamera = Cinemachine.VirtualCamera.new("PlayerCamera2D")

	-- Default to low priority (inactive).
	-- To enable, set Priority > PlayerCamera.Priority (e.g. via a camera manager script)
	playerCamera.Priority = GameEnums.CameraPriorities.Off
	Cinemachine.Brain:RefreshPriority()

	local cameraDistance = -50
	local cameraLookVector = Vector3.new(0, 0, 1)

	-- Offset: Position camera +100 studs on Z axis relative to player
	-- This results in looking towards -Z (standard Forward in Roblox)
	local followOffset = Vector3.new(0, 0, cameraDistance)
	local damping = Vector3.new(0, 0, 0)

	-- Use Transposer to follow player position with a fixed offset
	playerCamera.Body = Cinemachine.Components.Transposer.new(followOffset, damping)

	-- Calculate rotation based on the cameraLookVector
	-- CFrame.lookAt(at, target) creates a CFrame located at 'at' facing 'target'.
	-- By looking from Vector3.zero towards the lookVector, we get the correct orientation.
	playerCamera.State.Rotation = CFrame.lookAt(Vector3.zero, cameraLookVector)

	Cinemachine.Brain:Register(playerCamera)

	PlayerUtils.ObserveCharacterAdded(Player, function(character)
		-- Track HumanoidRootPart for 2D to avoid jitter from animation (Head bobbing)
		local rootPart = character:WaitForChild("HumanoidRootPart")
		playerCamera.Follow = rootPart

		-- NOTE: We purposefully do NOT set playerCamera.LookAt.
		-- This ensures the camera maintains its fixed 2D orientation
		-- instead of rotating to look at the player.
	end)

	return playerCamera
end

local Cameras = {}

Cameras.PlayerCamera = PlayerCamera()
Cameras.PlayerCamera2D = PlayerCamera2D()

return Cameras
