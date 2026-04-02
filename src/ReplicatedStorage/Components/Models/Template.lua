local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm

local Player = Players.LocalPlayer

local Template = Component.new({
	Tag = "Template",
	Ancestors = { Workspace },
})

function Template:Construct()
	self._Trove = Trove.new()
	self._Comm = ClientComm.new(self.Instance, true, "_Comm"):BuildObject()
end

function Template:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))

	self._Trove:Add(partStreamable:Observe(function(RootPart, loadedTrove)
		if RootPart then
			self:Loaded(RootPart, loadedTrove)
		end
	end))
end

function Template:Stop()
	self._Trove:Clean()
end

function Template:Loaded(RootPart, trove) end

return Template
