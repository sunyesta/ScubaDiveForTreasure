local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Template = Component.new({
	Tag = "Template",
	Ancestors = { Workspace },
})

function Template:Construct()
	self._Trove = Trove.new()
end

function Template:Start() end

function Template:Stop()
	self._Trove:Clean()
end

return Template
