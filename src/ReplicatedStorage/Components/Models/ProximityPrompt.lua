local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)

local ProximityPrompt = Component.new({
	Tag = "ProximityPrompt",
	Ancestors = { Workspace },
})
ProximityPrompt.Enabled = Property.new(true)

function ProximityPrompt:Construct()
	assert(self.Instance:IsA("ProximityPrompt"), "Must me a proximity prompt")

	self._Trove = Trove.new()
	self._ProxEnabled = Property.BindToAttribute(self.Instance, "ProxEnabled")
end

function ProximityPrompt:Start()
	local function updateEnabled()
		self:UpdateEnabled()
	end
	ProximityPrompt.Enabled:Observe(updateEnabled)
	self._ProxEnabled:Observe(updateEnabled)
end

function ProximityPrompt:Stop()
	self._Trove:Clean()
end

function ProximityPrompt:UpdateEnabled()
	if ProximityPrompt.Enabled:Get() and self._ProxEnabled:Get() then
		self.Instance.Enabled = true
	else
		self.Instance.Enabled = false
	end
end

return ProximityPrompt
