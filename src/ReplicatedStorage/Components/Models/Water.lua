local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable

local Player = Players.LocalPlayer

local Water = Component.new({
	Tag = "Water",
	Ancestors = { Workspace },
})

function Water:Construct()
	self._Trove = Trove.new()
end

function Water:Start()
	self.Instance.Size = Vector3.new(self.Instance.Size.X, self.Instance.Size.Y, 50)
end

function Water:Stop()
	self._Trove:Clean()
end

function Water:Loaded(rootPart, trove) end

return Water
