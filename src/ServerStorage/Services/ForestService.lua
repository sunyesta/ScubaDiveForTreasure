local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local ForestMapUtils = require(ServerStorage.Source.SecretModules.ForestMapUtils)
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

local ForestService = {}

function ForestService.GameStart()
	ForestService._DrawForest()
end

function ForestService._DrawForest()
	-- draws the forest
	-- use ForestMapUtils.GetMapPathData() to get the out and in ids and connect those ids with other path ids from other maps

	-- GetAssetByName()
end

function ForestService._LoadLevel() end

function ForestService._RequireLevel()
	-- loads a level if it hasn't been loaded yet and then returns
end

function ForestService._Enter() end

PlayerComm:BindFunction("UseForestPath", function(player, pathID)
	-- loads the forest level connected to the pathID and then teleports that player in front of the path
end)

PlayerComm:BindFunction("EnterForest", function(player)
	-- loads the forest level connected to the pathID and then teleports that player in front of the path
end)

return ForestService
