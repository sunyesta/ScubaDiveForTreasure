local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local ModelUtils = require(ReplicatedStorage.NonWallyPackages.ModelUtils)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ForestLevelDefinitions = require(ReplicatedStorage.Common.GameInfo.Forest.ForestLevelDefinitions)

function getLayoutPathData(layoutFolder, levelSeed)
	local OutPaths = TableUtil.Filter(layoutFolder:GetDescendants(), function(inst)
		return inst:HasTag("OutPath")
	end)

	return {
		InPathID = HttpService:GenerateGUID(false),
		OutPathIDs = TableUtil.Map(OutPaths, function(path)
			return HttpService:GenerateGUID(false) -- make it so that it has a unique value for each out path
		end),
	}
end

function setupPaths(layoutModel, layoutPathData)
	local inPath = InstanceUtils.FindFirstChildTagged(layoutModel, "InPath", true)
	local outPaths = TableUtil.Filter(layoutModel:GetDescendants(), function(inst)
		return inst:HasTag("OutPath")
	end)

	-- TODO assert that all the outPaths have unique names

	-- sort paths by name to keep consistent order
	table.sort(outPaths, function(out0, out1)
		return out0.Name < out1.Name
	end)

	inPath:SetAttribute("PathID", layoutPathData.InPathID)
	for i, outPath in outPaths do
		outPath:SetAttribute("PathID", layoutPathData.OutPathIDs)
	end
end

function buildBaseLayout(layoutFolder, layoutPathData, position, levelDefName, levelSeed)
	local layoutModel = ModelUtils.ConvertFolderToModel(layoutFolder:Clone())
	layoutModel:PivotTo(CFrame.new(position))
	setupPaths(layoutModel, layoutPathData)
	layoutModel.Position = true

	layoutModel:AddTag("ForestLevel")
	layoutModel:SetAttribute("levelDefName", levelDefName)
	layoutModel:SetAttribute("LevelSeed", levelSeed)

	layoutModel.Parent = workspace

	return layoutModel
end

function spawnEntityOnGround(layoutModel, modelTemplate, seed)
	local model = modelTemplate:Clone()
	model:SetAttribute("Seed", seed)
	local ground = InstanceUtils.GetTaggedDescendants(layoutModel, "Ground")

	local spawnPosition = nil --TODO set spawn position so that it only collides with ground. use getpartsinpart() to check
	modelTemplate:PivotTo(spawnPosition)
end

local BuildForestLayout = {}

local buildFuncs = {}

function buildFuncs.Treasure(levelSeed)
	local levelDefName = "Treasure"
	local levelDef = ForestLevelDefinitions.LevelDefinitions[levelDefName]
	local layoutFolder = GetAssetByName("LightForest01")
	local layoutPathData = getLayoutPathData(layoutFolder)
	return function(position)
		local trove = Trove.new()
		local layoutModel = trove:Add(buildBaseLayout(layoutFolder, layoutPathData, position, levelDefName, levelSeed))

		trove:Add(spawnEntityOnGround(layoutModel, GetAssetByName("ForestChest")), levelSeed)

		return trove
	end
end

return function(levelDefName, levelSeed)
	return buildFuncs[levelDefName](levelSeed)
end
