local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local ModelUtils = require(ReplicatedStorage.NonWallyPackages.ModelUtils)
local Trove = require(ReplicatedStorage.Packages.Trove)

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

function buildBaseLayout(layoutFolder, layoutPathData, position)
	local layoutModel = ModelUtils.ConvertFolderToModel(layoutFolder:Clone())
	layoutModel:PivotTo(CFrame.new(position))
	setupPaths(layoutModel, layoutPathData)

	layoutModel:SetAttribute("ExitsUnlocked", true)

	return layoutModel
end

function spawnEntityOnGround(layoutModel, modelTemplate)
	local ground = InstanceUtils.GetTaggedDescendants(layoutModel, "Ground")

	local spawnPosition = nil --TODO set spawn position so that it only collides with ground. use getpartsinpart() to check
	modelTemplate:PivotTo(spawnPosition)
end

local LayoutDefinitions = {}

function LayoutDefinitions.Treasure(actionData, levelSeed)
	local layoutFolder = GetAssetByName("LightForest01")
	local layoutPathData = getLayoutPathData(layoutFolder)
	return {
		LayoutPathData = layoutPathData,
		Build = function(position)
			local trove = Trove.new()
			local layoutModel = trove:Add(buildBaseLayout(layoutFolder, layoutPathData, position))

			trove:Add(spawnEntityOnGround(layoutModel, GetAssetByName("ForestChest")))

			return trove
		end,
	}
end

function LayoutDefinitions.Ambush(actionData, levelSeed)
	local layoutFolder = GetAssetByName("LightForest01")
	local layoutPathData = getLayoutPathData(layoutFolder)
	return {

		LayoutPathData = layoutPathData,
		Build = function(position, playerWhoEnteredFirst)
			local trove = Trove.new()
			local layoutModel = trove:Add(buildBaseLayout(layoutFolder, layoutPathData, position))

			local completedLevels = playerWhoEnteredFirst:GetAttribute("CompletedLevels")
			if not completedLevels[level] then
				layoutModel:SetAttribute("ExitsUnlocked", false)
				for _, entity in actionData.Entities do
					trove:Add(spawnEntityOnGround(layoutModel, GetAssetByName(entity)))
				end
				-- todo wait for all the spawned entities to die before spawning the next wave
			end

			-- todo wait for all entities to be dead before unlocking the exits
			layoutModel:SetAttribute("ExitsUnlocked", true)

			return trove
		end,
	}
end

return LayoutDefinitions
