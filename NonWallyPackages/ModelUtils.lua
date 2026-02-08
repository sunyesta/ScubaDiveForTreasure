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

return ModelUtils
