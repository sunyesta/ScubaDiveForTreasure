local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LayeredTexture = require(script.LayeredTexture)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local CustomMaterial = {}
CustomMaterial.__index = CustomMaterial

CustomMaterial.LayeredTexture = LayeredTexture

function CustomMaterial.new(basePart)
	local self = setmetatable({}, CustomMaterial)

	self._Trove = Trove.new()
	self._BasePart = basePart

	self.LayeredTexture = self._Trove:Add(LayeredTexture.CreateProperties(basePart))

	self.Changed = self._Trove:Add(Signal.new())

	local function fireChanged()
		self.Changed:Fire()
	end

	self.LayeredTexture.TextureLayers.Changed:Connect(fireChanged)
	self.LayeredTexture.TextureScale.Changed:Connect(fireChanged)

	return self
end

function CustomMaterial:Destroy()
	self._Trove:Clean()
end

function CustomMaterial:GetBasePart()
	return self._BasePart
end

function CustomMaterial.Save(basePart)
	return { LayeredTexture = LayeredTexture.Save(basePart) }
end

function CustomMaterial.Load(basePart, savedData)
	LayeredTexture.Load(basePart, savedData.LayeredTexture)
end

function CustomMaterial.SaveFromModel(model)
	local materialPerPart = {}
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			local path = InstanceUtils.GetPath(model, inst)
			materialPerPart[path] = CustomMaterial.Save(inst)
		end
	end

	return materialPerPart
end

function CustomMaterial.LoadToModel(model, materialPerPart)
	for path, materialData in materialPerPart do
		local part = InstanceUtils.GetInstFromPath(model, path)
		if part then
			CustomMaterial.Load(part, materialData)
		else
			warn(model, ".", path, "not found")
		end
	end
end

return CustomMaterial
