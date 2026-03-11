local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BuildForestLevel = require(ServerStorage.Source.SecretModules.BuildForestLevel)
local ForestLevelDefinitions = require(ReplicatedStorage.Common.GameInfo.Forest.ForestLevelDefinitions)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)
local PlayerComm = PlayerContext.Client.Comm

local ForestLevelDefNames = TableUtil.Keys(ForestLevelDefinitions.LevelDefinitions)

local ForestService = {}

function ForestService.GameStart()
	ForestService._DrawForest()
end

function ForestService._DrawForest(seed)
	-- draws the forest
end

function ForestService._LoadLevel() end

function ForestService._RequireLevel()
	-- loads a level if it hasn't been loaded yet and then returns
end

function ForestService.TeleportPlayerToNextLevel(player) end

function ForestService.LeaveForest() end

PlayerComm:BindFunction("EnterForest", function(player)
	-- loads the forest level connected to the pathID and then teleports that player in front of the path
end)

return ForestService
