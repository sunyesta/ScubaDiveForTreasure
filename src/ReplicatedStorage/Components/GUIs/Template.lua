--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentRegistry = require(ReplicatedStorage.NonWallyPackages.ComponentRegistry)
local Trove = require(ReplicatedStorage.Packages.Trove)

--Instances
local Player = Players.LocalPlayer

local Template = Component.new({
	Tag = "Template",
	Ancestors = { Player },
})
-- Template.RequireAtLeast1 = true
ComponentRegistry.Register(Template)

function Template:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()
end

function Template:Start() end

function Template:Stop()
	self._Trove:Clean()
end

function Template.Open()
	local self = Template:GetAll()[1]
end

function Template.Close()
	local self = Template:GetAll()[1]
	self._OpenTrove:Clean()
end

return Template
