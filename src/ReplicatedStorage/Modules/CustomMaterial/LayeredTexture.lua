local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local Signal = require(ReplicatedStorage.Packages.Signal)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Assert = require(ReplicatedStorage.NonWallyPackages.Assert)
local Serializer = require(ReplicatedStorage.NonWallyPackages.Serializer)
local ClientComm, ServerComm, LayeredTextureComm, DeleteClientTextures

local LayeredTexture = {}
LayeredTexture.__index = LayeredTexture

LayeredTexture.ExampleTextureLayer = {
	TextureColor = Color3.new(),
	TextureID = "", -- set to nil on first layer if you want to set the basecolor
}

LayeredTexture.Attributes = {
	TextureLayers = "LayeredTexture_TextureLayers",
	TextureScale = "LayeredTexture_Scale",
	TextureAttributeName = "LayeredTexture_Texture",
}

-- Private Methods

function LayeredTexture._SerializeTextureLayers(textureLayers, toString)
	local newTextureLayers = table.create(#textureLayers)
	for i = 1, #textureLayers do
		newTextureLayers[i] = {}
		newTextureLayers[i].TextureColor = Serializer.Serialize(textureLayers[i].TextureColor)
		newTextureLayers[i].TextureID = textureLayers[i].TextureID
	end

	return if toString then TableUtil.EncodeJSON(newTextureLayers) else newTextureLayers
end

function LayeredTexture._DeserializeTextureLayers(textureLayers, fromString)
	textureLayers = if fromString then TableUtil.DecodeJSON(textureLayers) else textureLayers

	for _, layer in textureLayers do
		layer.TextureColor = Serializer.Deserialize("Color3", layer.TextureColor)
	end

	return textureLayers
end

-- Public Methods

function LayeredTexture.ApplyTextureScale(basePart: BasePart, scale: number)
	-- destroy all client textures
	for _, inst in basePart:GetChildren() do
		if inst:GetAttribute(LayeredTexture.Attributes.TextureAttributeName) then
			inst.StudsPerTileU = scale
			inst.StudsPerTileV = scale
		end
	end

	print("scale = ", scale)
	basePart:SetAttribute(LayeredTexture.Attributes.TextureScale, scale)
end

function LayeredTexture.GetTextureScale(basePart: BasePart)
	local textureScale = basePart:GetAttribute(LayeredTexture.Attributes.TextureScale)

	if textureScale then
		return textureScale
	else
		local texture = InstanceUtils.FindFirstChild(basePart, false, function(inst)
			return inst:GetAttribute(LayeredTexture.Attributes.TextureAttributeName)
		end)

		if texture then
			basePart:SetAttribute(LayeredTexture.Attributes.TextureScale, texture.StudsPerTileU)
			return texture.StudsPerTileU
		else
			return 10
		end
	end
end

function LayeredTexture.ApplyTextureLayers(basepart: BasePart, textureLayers)
	-- delete old textures
	for _, inst in basepart:GetChildren() do
		if inst:GetAttribute(LayeredTexture.Attributes.TextureAttributeName) then
			inst:Destroy()
		end
	end

	-- create new textures
	for i, layer in textureLayers do
		if i == 1 and layer.TextureID == nil then
			local surfaceAppearance = basepart:FindFirstChildWhichIsA("SurfaceAppearance")
			if surfaceAppearance then
				surfaceAppearance.Color = layer.TextureColor
			else
				basepart.Color = layer.TextureColor
			end
		else
			for _, face in Enum.NormalId:GetEnumItems() do
				local Texture = Instance.new("Texture")
				Texture:SetAttribute(LayeredTexture.Attributes.TextureAttributeName, true)
				Texture.Face = face
				Texture.Parent = basepart
				Texture.Texture = layer.TextureID
				Texture.Color3 = layer.TextureColor
				Texture.ZIndex = i

				local textureScale = LayeredTexture.GetTextureScale(basepart)
				Texture.StudsPerTileU = textureScale
				Texture.StudsPerTileV = textureScale

				if RunService:IsClient() then
					Texture:SetAttribute("ClientOnly", true)
				end
			end
		end
	end

	-- Update the attribute with the serialized texture layers

	basepart:SetAttribute(
		LayeredTexture.Attributes.TextureLayers,
		LayeredTexture._SerializeTextureLayers(textureLayers, true)
	)
end

function LayeredTexture.UpdateTextureLayerColors(basepart: BasePart, textureColors)
	local textureLayers = LayeredTexture.GetTextureLayers(basepart)

	assert(
		#textureLayers == #textureColors,
		"layer count " .. #textureLayers .. " doesn't equal color count " .. #textureColors
	)

	for _, inst in basepart:GetChildren() do
		if inst:GetAttribute(LayeredTexture.Attributes.TextureAttributeName) then
			local layerIndex = inst.ZIndex
			local layer = textureLayers[layerIndex]

			assert(
				typeof(textureColors[layerIndex]) == "Color3",
				"invalid color" .. tostring(textureColors[layerIndex])
			)

			local newLayerColor = textureColors[layerIndex]
			layer.TextureColor = newLayerColor
			inst.Color3 = newLayerColor
		end
	end

	if textureLayers[1].TextureID == nil then
		local newLayerColor = textureColors[1]

		textureLayers[1].TextureColor = newLayerColor

		local surfaceAppearance = basepart:FindFirstChildWhichIsA("SurfaceAppearance")
		if surfaceAppearance then
			surfaceAppearance.Color = newLayerColor
		else
			basepart.Color = newLayerColor
		end
	end

	basepart:SetAttribute(
		LayeredTexture.Attributes.TextureLayers,
		LayeredTexture._SerializeTextureLayers(textureLayers, true)
	)
end

function LayeredTexture.UpdateSingleLayerColor(basepart: BasePart, layerIndex, color)
	local textureColors = LayeredTexture.GetTextureLayerColors(LayeredTexture.GetTextureLayers(basepart))

	assert(layerIndex <= #textureColors, "index not in bounds" .. tostring(layerIndex))

	textureColors[layerIndex] = color
	LayeredTexture.UpdateTextureLayerColors(basepart, textureColors)
end

function LayeredTexture.GetTextureLayerColors(textureLayers)
	return TableUtil.Map(textureLayers, function(layer)
		return layer.TextureColor
	end)
end

function LayeredTexture.GetTextureLayers(basepart)
	local textureLayers = basepart:GetAttribute(LayeredTexture.Attributes.TextureLayers)

	if textureLayers then
		textureLayers = LayeredTexture._DeserializeTextureLayers(textureLayers, true)
	else
		local surfaceAppearance = basepart:FindFirstChildWhichIsA("SurfaceAppearance")
		local baseColor = if surfaceAppearance then surfaceAppearance.Color else basepart.Color

		textureLayers = { { TextureID = nil, TextureColor = baseColor } }
	end

	return textureLayers
end

function LayeredTexture.Save(basePart: BasePart)
	local textureScale = LayeredTexture.GetTextureScale(basePart)
	local textureLayersSerialized =
		LayeredTexture._SerializeTextureLayers(LayeredTexture.GetTextureLayers(basePart), false)

	return { textureScale, textureLayersSerialized }
end

function LayeredTexture.Load(basePart: BasePart, savedData)
	local textureScale = savedData[1]
	local textureLayers = LayeredTexture._DeserializeTextureLayers(savedData[2], false)

	LayeredTexture.ApplyTextureScale(basePart, textureScale)
	LayeredTexture.ApplyTextureLayers(basePart, textureLayers)
end

local PropertyFuncs = {}
PropertyFuncs.__index = PropertyFuncs
function PropertyFuncs:Destroy()
	self._Trove:Clean()
end

function LayeredTexture.CreateProperties(basepart)
	local self = setmetatable({}, PropertyFuncs)

	self._Trove = Trove.new()
	local _textureLayers = Property.new(LayeredTexture.GetTextureLayers(basepart), true, true)
	local _textureScale = Property.new(LayeredTexture.GetTextureScale(basepart))
	self.TextureLayers = Property.ReadOnly(_textureLayers)
	self.TextureScale = Property.ReadOnly(_textureScale)

	-- sync self._TextureLayers with attribute
	local oldTextureLayersSTR = nil
	self._Trove:Add(basepart:GetAttributeChangedSignal(LayeredTexture.Attributes.TextureLayers):Connect(function()
		local textureLayersSTR = basepart:GetAttribute(LayeredTexture.Attributes.TextureLayers)
		if textureLayersSTR ~= oldTextureLayersSTR then
			_textureLayers:Set(LayeredTexture._DeserializeTextureLayers(textureLayersSTR, true))
		end
		oldTextureLayersSTR = textureLayersSTR
	end))

	-- sync self._TextureLayers with attribute

	self._Trove:Add(basepart:GetAttributeChangedSignal(LayeredTexture.Attributes.TextureScale):Connect(function()
		_textureScale:Set(basepart:GetAttribute(LayeredTexture.Attributes.TextureScale))
	end))

	return self
end

function LayeredTexture:GetBasePart()
	return self._BasePart
end

-- Comms
if RunService:IsServer() then
	ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
	LayeredTextureComm = ServerComm.new(ReplicatedStorage.Comm, "LayeredTexture")
	DeleteClientTextures = LayeredTextureComm:CreateSignal("DeleteClientTextures")
else
	ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm

	task.spawn(function()
		LayeredTextureComm = ClientComm.new(ReplicatedStorage.Comm, true, "LayeredTexture"):BuildObject()
		DeleteClientTextures = LayeredTextureComm.DeleteClientTextures

		DeleteClientTextures:Connect(function(basepart)
			-- if basepart has not been created on client yet, then don't do anything
			if not basepart then
				return
			end

			-- destroy all client textures
			for _, inst in basepart:GetChildren() do
				if
					inst:GetAttribute(LayeredTexture.Attributes.TextureAttributeName)
					and inst:GetAttribute("ClientOnly")
				then
					inst:Destroy()
				end
			end
		end)
	end)
end

return LayeredTexture
