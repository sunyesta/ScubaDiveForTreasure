local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local InventoryService = require(ServerStorage.Source.Services.InventoryService)

local OxygenCoral = Component.new({
	Tag = "OxygenCoral",
	Ancestors = { Workspace },
})

function OxygenCoral:Construct()
	self._Trove = Trove.new()
	self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm1"))
end

function OxygenCoral:Start()
	self._Comm:BindFunction("Harvest", function(player)
		InventoryService.GiveItem(player, "OxygenCoral")
	end)
end

function OxygenCoral:Stop()
	self._Trove:Clean()
end

return OxygenCoral
