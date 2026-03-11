--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)

--Instances
local Player = Players.LocalPlayer

local Template = Component.new({
	Tag = "Template",
	Ancestors = { Player },
})
Template.IsOpen = Property.new(false)
-- Template.Singleton = true

function Template:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()
end

function Template:Start() end

function Template:Stop()
	self._Trove:Clean()
end

function Template.Open()
	if Template.IsOpen:Get() then
		return
	end
	local self = Template:GetAll()[1]

	Template.IsOpen:Set(true)
	self._OpenTrove:Add(function()
		Template.IsOpen:Set(false)
	end)
end

function Template.Close()
	local self = Template:GetAll()[1]
	self._OpenTrove:Clean()
end

return Template
