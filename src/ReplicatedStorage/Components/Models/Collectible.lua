local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable

local Player = Players.LocalPlayer

local Collectible = Component.new({
	Tag = "Collectible",
	Ancestors = { Workspace },
})

function Collectible:Construct()
	self._Trove = Trove.new()
end

function Collectible:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))

	self._Trove:Add(partStreamable:Observe(function(rootPart, loadedTrove)
		if rootPart then
			self:Loaded(rootPart, loadedTrove)
		end
	end))
end

function Collectible:Stop()
	self._Trove:Clean()
end

function Collectible:Loaded(rootPart, trove) end

return Collectible
