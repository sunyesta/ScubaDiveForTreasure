-- This script sets up the perfect underwater environment using modern Lighting features.
-- Place this script inside ServerScriptService.

local Lighting = game:GetService("Lighting")

-- ==========================================
-- ⚙️ CONFIGURATION
-- Tweak these values to change the water's mood
-- ==========================================
local WATER_SETTINGS = {
	Ambient = Color3.fromRGB(15, 35, 60), -- Base shadow color
	OutdoorAmbient = Color3.fromRGB(20, 50, 80), -- Light hitting from the "sky"
	Brightness = 1.2, -- Overall brightness

	-- Fog / Visibility
	FogColor = Color3.fromRGB(10, 35, 60),
	FogEnd = 300, -- How far until completely invisible

	-- Atmosphere (Volumetric Depth)
	AtmosphereDensity = 0.45,
	AtmosphereColor = Color3.fromRGB(20, 70, 105),
	AtmosphereDecay = Color3.fromRGB(5, 20, 35), -- The color water fades to in the distance

	-- Color Correction (Screen Tint)
	ScreenTint = Color3.fromRGB(180, 230, 255), -- Washes the screen in a watery hue
	Contrast = 0.15,
	Saturation = -0.1, -- Desaturate slightly for realism

	-- Blur / Depth of Field
	BlurDistance = 25, -- Distance where objects start to blur
	BlurIntensity = 0.6,
}

-- ==========================================
-- 🛠️ IMPLEMENTATION
-- ==========================================
local function setupUnderwaterLighting()
	-- 1. Apply base lighting properties
	Lighting.Ambient = WATER_SETTINGS.Ambient
	Lighting.OutdoorAmbient = WATER_SETTINGS.OutdoorAmbient
	Lighting.Brightness = WATER_SETTINGS.Brightness
	Lighting.FogColor = WATER_SETTINGS.FogColor
	Lighting.FogStart = 0
	Lighting.FogEnd = WATER_SETTINGS.FogEnd
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.Future -- Ensure we are using the best lighting tech

	-- 2. Setup Atmosphere for realistic volumetric water
	-- We check if one exists to avoid duplicates, otherwise we create a new one
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "UnderwaterAtmosphere"
		atmosphere.Parent = Lighting -- Parenting last is a Roblox best practice!
	end

	atmosphere.Density = WATER_SETTINGS.AtmosphereDensity
	atmosphere.Offset = 0
	atmosphere.Color = WATER_SETTINGS.AtmosphereColor
	atmosphere.Decay = WATER_SETTINGS.AtmosphereDecay
	atmosphere.Glare = 0
	atmosphere.Haze = 2 -- High haze diffuses light, like murky water

	-- 3. Setup Color Correction for the watery screen tint
	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "UnderwaterColorCorrection"
		colorCorrection.Parent = Lighting
	end

	colorCorrection.TintColor = WATER_SETTINGS.ScreenTint
	colorCorrection.Contrast = WATER_SETTINGS.Contrast
	colorCorrection.Saturation = WATER_SETTINGS.Saturation

	-- 4. Setup Depth of Field to blur distant objects
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if not dof then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "UnderwaterDepthOfField"
		dof.Parent = Lighting
	end

	dof.FocusDistance = WATER_SETTINGS.BlurDistance
	dof.InFocusRadius = 15
	dof.NearIntensity = 0
	dof.FarIntensity = WATER_SETTINGS.BlurIntensity

	print("🌊 Underwater lighting successfully generated!")
end

-- Run the setup function
setupUnderwaterLighting()
