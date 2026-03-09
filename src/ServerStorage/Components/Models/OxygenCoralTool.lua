local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm

local OxygenCoralTool = Component.new({
	Tag = "OxygenCoralTool",
	Ancestors = { Workspace },
})

function OxygenCoralTool:Construct()
	self._Trove = Trove.new()
	self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm"))
end

function OxygenCoralTool:Start()
	self.Instance.Activated:Connect(function()
		self.Instance:Destroy()
	end)
end

function OxygenCoralTool:Stop()
	self._Trove:Clean()
end

return OxygenCoralTool
