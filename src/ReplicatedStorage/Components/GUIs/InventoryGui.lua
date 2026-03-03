--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentRegistry = require(ReplicatedStorage.NonWallyPackages.ComponentRegistry)
local Trove = require(ReplicatedStorage.Packages.Trove)

--Instances
local Player = Players.LocalPlayer

local InventoryGui = Component.new({
	Tag = "InventoryGui",
	Ancestors = { Player },
})
InventoryGui.Singleton = true

function InventoryGui:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()
end

function InventoryGui:Start() end

function InventoryGui:Stop()
	self._Trove:Clean()
end

function InventoryGui.Open()
	local self = InventoryGui:GetAll()[1]
end

function InventoryGui.Close()
	local self = InventoryGui:GetAll()[1]
	self._OpenTrove:Clean()
end

return InventoryGui
