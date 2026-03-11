local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local ForestService = require(ServerStorage.Source.Services.ForestService)
local ForestLevelDefinitions = require(ReplicatedStorage.Common.GameInfo.Forest.ForestLevelDefinitions)

local ForestLevel = Component.new({
	Tag = "ForestLevel",
	Ancestors = { Workspace },
})

function ForestLevel:Construct()
	self._Trove = Trove.new()
	self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm"))
	self.ExitUnlocked = Property.new(true)

	self.LevelDef = ForestLevelDefinitions.LevelDefinitions[self.Instance:GetAttribute("LevelDefName")]
	self.Seed = self:GetAttribute("LevelSeed")
end

function ForestLevel:Start()
	self._Comm:BindFunction("NextLevel", function(player)
		if self.ExitUnlocked:Get() then
			ForestService.TeleportPlayerToNextLevel(player)
		end
	end)
end

function ForestLevel:Stop()
	self._Trove:Clean()
end

return ForestLevel
