local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.NonWallyPackages.Assert)
local WeldUtils = require(ReplicatedStorage.NonWallyPackages.WeldUtils)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local CustomMaterial = require(ReplicatedStorage.Common.Modules.CustomMaterial)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local Serializer = require(ReplicatedStorage.NonWallyPackages.Serializer)

local ModelEditorUtils = {}
ModelEditorUtils.WELD_NAME = "ModelEditorWeld"
ModelEditorUtils.NOT_INTERACTIVE_ATTRIBUTE_NAME = "NonInteractive"

function ModelEditorUtils.PlaceOn(model, otherPart, cframe)
	Assert(
		otherPart and (otherPart.Parent == workspace or workspace:IsAncestorOf(otherPart.Parent)),
		otherPart,
		"is invalid"
	)

	local weld = ModelEditorUtils.RequireWeld(model)
	weld.Enabled = false

	if cframe then
		model:PivotTo(cframe)
	end

	WeldUtils.Weld(model.PrimaryPart, otherPart, weld)
	weld.Enabled = true
end

function ModelEditorUtils.RequireWeld(model)
	local weld = model:FindFirstChild(ModelEditorUtils.WELD_NAME)

	if not weld then
		weld = Instance.new("WeldConstraint")
		weld.Name = ModelEditorUtils.WELD_NAME
		weld.Parent = model
	end

	return weld
end

function ModelEditorUtils.DisableWeld(model)
	local weld = ModelEditorUtils.RequireWeld(model)
	weld.Enabled = false
end

function ModelEditorUtils.BreakWeld(model)
	local weld = ModelEditorUtils.RequireWeld(model)
	weld.Part1 = nil
end

function ModelEditorUtils.GetWeldedPart(model)
	return model:FindFirstChild(ModelEditorUtils.WELD_NAME).Part1
end

function ModelEditorUtils.Save(buildPlatform, folder)
	local modelDataList = {}
	for _, model in folder:GetChildren() do
		local weldTo = ModelEditorUtils.GetWeldedPart(model)

		local modelData = {
			Name = model.Name,
			AssetName = model:GetAttribute("AssetName"),
			WeldToPath = if weldTo and weldTo:IsDescendantOf(folder)
				then InstanceUtils.GetPath(folder, weldTo)
				else nil, --incase the WeldTo doesn't exist on server yet
			CFrameOffset = Serializer.Serialize(buildPlatform:GetPivot():ToObjectSpace(model:GetPivot())),
			Scale = model:GetScale(),
			Materials = CustomMaterial.SaveFromModel(model),
		}

		table.insert(modelDataList, modelData)
	end

	return modelDataList
end

function ModelEditorUtils.Load(buildPlatform, parent, data)
	local models = {}
	for _, modelData in data do
		local model = ModelEditorUtils.CreateModel(modelData.AssetName)
		model.Name = modelData.Name
		model.Parent = parent
		model:ScaleTo(modelData.Scale)

		modelData.CFrameOffset = Serializer.Deserialize("CFrame", modelData.CFrameOffset)
		model:PivotTo(buildPlatform:GetPivot():ToWorldSpace(modelData.CFrameOffset))
		CustomMaterial.LoadToModel(model, modelData.Materials)
		modelData.Model = model
		models[model.Name] = model
	end

	for _, modelData in data do
		local weldTo = if modelData.WeldToPath
			then InstanceUtils.GetInstFromPath(parent, modelData.WeldToPath)
			else buildPlatform
		ModelEditorUtils.PlaceOn(modelData.Model, weldTo)
	end

	return TableUtil.Values(models)
end

function ModelEditorUtils.CreateModel(assetName)
	local refModel = GetAssetByName(assetName)

	Assert(refModel:HasTag("AssemblyModel"), assetName, "model must be an assembly model")

	-- create model
	local model = refModel:Clone()
	model:SetAttribute("AssetName", assetName)

	model.PrimaryPart.Anchored = false

	return model
end

function ModelEditorUtils.CanPlace(player, canPlaceFunc, model, cframe, placeOn)
	cframe = cframe or model:GetPivot()
	placeOn = placeOn or ModelEditorUtils.GetWeldedPart(model)

	return canPlaceFunc(player, model, cframe, placeOn)
end

return ModelEditorUtils
