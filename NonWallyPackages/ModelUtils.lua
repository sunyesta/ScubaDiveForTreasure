local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BasePartUtils = require(ReplicatedStorage.NonWallyPackages.BasePartUtils)
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local ModelUtils = {}

function ModelUtils.SetCollisionGroup(model, collisionGroup)
	ModelUtils.ApplyToAllBaseParts(model, function(part)
		part.CollisionGroup = collisionGroup
	end)
end

function ModelUtils.ApplyToAllBaseParts(model, callback)
	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			callback(part)
		end
	end
end

function ModelUtils.SetCanCollide(model, canCollide)
	ModelUtils.ApplyToAllBaseParts(model, function(part)
		part.CanCollide = canCollide
	end)
end

function ModelUtils.ScaleToPivot(model, scale)
	local function scaleToPivot(pivotPos, partPos, scaleFactor)
		return Vector3.new(
			(pivotPos.X + scaleFactor * (partPos.X - pivotPos.X)),
			(pivotPos.Y + scaleFactor * (partPos.Y - pivotPos.Y)),
			(pivotPos.Z + scaleFactor * (partPos.Z - pivotPos.Z))
		)
	end

	local pivotPos = model:GetPivot().Position

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Size *= Vector3.new(scale, scale, scale)
			part.Position = scaleToPivot(pivotPos, part.Position, scale)
		end
	end
	-- if using PrimaryPart, scale the PivotOffset
	if model.PrimaryPart then
		model.PrimaryPart.PivotOffset = CFrame.new(model.PrimaryPart.PivotOffset.Position * scale)
	end
end

function ModelUtils.GetPartsInModel(model, worldModel)
	worldModel = worldModel or workspace
	local insideParts = {}

	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			for _, part in worldModel:GetPartsInPart(inst) do
				insideParts[part] = true
			end
		end
	end

	-- remove any parts that were part of the model
	for _, inst in model:GetDescendants() do
		insideParts[inst] = nil
	end

	return insideParts
end

--[[
    Title: Folder to Model Converter
    Description: Converts a Folder instance into a Model, preserves children,
                 and automatically assigns the largest BasePart as the PrimaryPart
                 if one isn't explicitly provided.
    Location: ReplicatedStorage (as a ModuleScript) or ServerScriptService (as a helper)
--]]

function ModelUtils.ConvertFolderToModel(folder: Folder, primaryPart: BasePart?): Model
	-- 1. Create the new Model container
	local newModel = Instance.new("Model")
	newModel.Name = folder.Name
	newModel.Parent = folder.Parent -- Keep it in the same hierarchy spot

	-- 2. Move all children from Folder to Model
	-- We use a variable for children to avoid issues with the live collection changing
	local children = folder:GetChildren()
	for _, child in children do
		child.Parent = newModel
	end

	-- 3. Determine the PrimaryPart
	if primaryPart and primaryPart:IsDescendantOf(newModel) then
		-- Use the provided part if it exists and was moved into the model
		newModel.PrimaryPart = primaryPart
	else
		-- Logic to find the "biggest" part by volume
		local biggestPart: BasePart? = nil
		local maxVolume = 0

		for _, descendant in newModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				-- Calculate Volume: Width * Height * Depth
				local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z

				if volume > maxVolume then
					maxVolume = volume
					biggestPart = descendant
				end
			end
		end

		if biggestPart then
			newModel.PrimaryPart = biggestPart
		end
	end

	-- 4. Clean up the old folder
	folder:Destroy()

	return newModel
end

return ModelUtils
