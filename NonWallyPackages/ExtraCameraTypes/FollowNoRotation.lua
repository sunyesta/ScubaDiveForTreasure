local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DefaultValue = require(ReplicatedStorage.NonWallyPackages.DefaultValue)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local FollowNoRotation = {}
FollowNoRotation.__index = FollowNoRotation
-- local camera = Workspace.CurrentCamera

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local CurrentCamera = Workspace.CurrentCamera

function FollowNoRotation.new(camera, subject)
	-- default params
	camera = camera or CurrentCamera
	subject = subject or Player.Character

	local self = setmetatable({}, FollowNoRotation)
	self._Trove = Trove.new()

	camera:SetAttribute("CameraType", "FollowNoRotation")
	self._Trove:Add(function()
		camera:SetAttribute("CameraType", nil)
	end)

	local ZoomLevel = (camera.Focus.Position - camera.CFrame.Position).Magnitude
	local curRotation = camera.CFrame.Rotation
	local desiredRotation = camera.CFrame.Rotation

	local updateRotation = false

	local origCFrameOffset = CFrame.new(subject:GetPivot().Position):ToObjectSpace(camera.CFrame)
	camera.CameraType = Enum.CameraType.Scriptable

	self._Trove:Add(RunService.RenderStepped:Connect(function(deltaTime)
		camera.CFrame = CFrame.new(subject:GetPivot().Position) * origCFrameOffset
	end))

	self._Trove:Add(UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			updateRotation = true
		end
	end))

	self._Trove:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			updateRotation = false
		end
	end))

	self._Trove:Add(camera.Changed:Connect(function(property)
		if property == "CameraType" then
			self._Trove:Clean()
		end
	end))

	return self
end

function FollowNoRotation:Destroy()
	self._Trove:Clean()
end

return FollowNoRotation
