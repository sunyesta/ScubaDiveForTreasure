--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentRegistry = require(ReplicatedStorage.NonWallyPackages.ComponentRegistry)
local Trove = require(ReplicatedStorage.Packages.Trove)
local MovementController = require(ReplicatedStorage.Common.Controllers.MovementController)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local OxygenController = require(ReplicatedStorage.Common.Controllers.OxygenController)

--Instances
local Player = Players.LocalPlayer
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

local MainGui = Component.new({
	Tag = "MainGui",
	Ancestors = { Player },
})
-- MainGui.Singleton = true

function MainGui:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()

	self._Oxygen = OxygenController.Oxygen
	self._MaxOxygen = Property.BindToCommProperty(PlayerComm.MaxOxygen)
end

function MainGui:Start()
	MainGui.Open()
end

function MainGui:Stop()
	self._Trove:Clean()
end

function MainGui.Open()
	local self = MainGui:GetAll()[1]

	self._OpenTrove:Add(self.Instance.TextButton.MouseButton1Down:Connect(function()
		print("ya", MovementController.CurrentMovementMode:Get())
		if MovementController.CurrentMovementMode:Get() == MovementController.MovementModes.Moving2D then
			MovementController.CurrentMovementMode:Set(MovementController.MovementModes.Normal)
		else
			MovementController.CurrentMovementMode:Set(MovementController.MovementModes.Moving2D)
		end
	end))

	local function updateO2()
		local oxygen, maxOxygen = self._Oxygen:Get(), self._MaxOxygen:Get()
		self.Instance.OxygenLabel.Text = math.round(oxygen) .. " / " .. maxOxygen
	end

	self._OpenTrove:Add(self._MaxOxygen:Observe(updateO2))
	self._OpenTrove:Add(self._Oxygen:Observe(updateO2))
end

function MainGui.Close()
	local self = MainGui:GetAll()[1]
	self._OpenTrove:Clean()
end

return MainGui
