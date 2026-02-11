--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentRegistry = require(ReplicatedStorage.NonWallyPackages.ComponentRegistry)
local Trove = require(ReplicatedStorage.Packages.Trove)
local MovementController = require(ReplicatedStorage.Common.Controllers.MovementController)

--Instances
local Player = Players.LocalPlayer

local MainGui = Component.new({
	Tag = "MainGui",
	Ancestors = { Player },
})
-- MainGui.RequireAtLeast1 = true
ComponentRegistry.Register(MainGui)

function MainGui:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()
end

function MainGui:Start()
	self.Instance.TextButton.MouseButton1Down:Connect(function()
		print("ya", MovementController.CurrentMovementMode:Get())
		if MovementController.CurrentMovementMode:Get() == MovementController.MovementModes.Moving2D then
			MovementController.CurrentMovementMode:Set(MovementController.MovementModes.Normal)
		else
			MovementController.CurrentMovementMode:Set(MovementController.MovementModes.Moving2D)
		end
	end)
end

function MainGui:Stop()
	self._Trove:Clean()
end

function MainGui.Open()
	local self = MainGui:GetAll()[1]
end

function MainGui.Close()
	local self = MainGui:GetAll()[1]
	self._OpenTrove:Clean()
end

return MainGui
