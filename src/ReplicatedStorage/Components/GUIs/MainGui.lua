--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm

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
end

function MainGui:Start()
	MainGui.Open()
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
