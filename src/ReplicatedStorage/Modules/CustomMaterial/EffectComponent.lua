--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
--packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)

local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local serverComm = ServerComm.new(ReplicatedStorage.Comm, "ToolComm")

--Instances

local Tool = Component.new({
	Tag = "Tool",
	Ancestors = { Workspace },
	Extensions = {},
})

function Tool:Construct()
	assert(self.Instance:IsA("Model"), "Tool Must be a model")

	self.Trove = Trove.new()
	self.ActivePlayer = nil
	self.Triggered = self.Trove:Add(Signal.new())
	self.Handle = self.Instance.Handle
	self.Equipped = Property.new(false)
end

function Tool:Start()
	if not self.Instance.PrimaryPart then
		self.Instance.PrimaryPart = self.Instance.Handle
	end
	self.Handle.PivotOffset = self.Handle.Grip.CFrame

	self.Instance:AddTag("DraggablePart")

	self.Trove:Add(self.Equipped:Observe(function(equipped)
		if equipped then
			self.Handle.Massless = true
		else
			self.Handle.Massless = false
		end
	end))
end

function Tool:Stop()
	self.Trove:Clean()
end

function Tool:Trigger()
	self.Triggered:Fire()
end

serverComm:BindFunction("Trigger", function(player, obj)
	local tool = Tool:FromInstance(obj)
	assert(tool, "tool not found")
	tool:Trigger()
end)

return Tool
