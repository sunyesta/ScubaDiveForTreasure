--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentRegistry = require(ReplicatedStorage.NonWallyPackages.ComponentRegistry)
local Trove = require(ReplicatedStorage.Packages.Trove)

--Instances
local Player = Players.LocalPlayer

local StartLoadingScreen = Component.new({
	Tag = "StartLoadingScreen",
	Ancestors = { Player },
})
-- StartLoadingScreen.RequireAtLeast1 = true
ComponentRegistry.Register(StartLoadingScreen)

function StartLoadingScreen:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()
	self.Instance.Enabled = false
end

function StartLoadingScreen:Start() end

function StartLoadingScreen:Stop()
	self._Trove:Clean()
end

function StartLoadingScreen.Open()
	local self = StartLoadingScreen:GetAll()[1]
	self.Instance.Enabled = true

	self._OpenTrove:Add(function()
		self.Instance.Enabled = false
	end)
end

function StartLoadingScreen.Close()
	local self = StartLoadingScreen:GetAll()[1]
	self._OpenTrove:Clean()
end

function StartLoadingScreen.UpdateStatus(message)
	local self = StartLoadingScreen:GetAll()[1]

	local StatusLabel = self.Instance.Frame.StatusLabel
	if StatusLabel then
		StatusLabel.Text = message
	end
end

return StartLoadingScreen
