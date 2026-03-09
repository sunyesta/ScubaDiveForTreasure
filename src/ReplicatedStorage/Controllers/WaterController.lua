local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Assuming these are your custom utility modules
local SoundUtils = require(ReplicatedStorage.NonWallyPackages.SoundUtils)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local Teleporter = require(ReplicatedStorage.Common.Components.Models.Teleporter)

local Player = Players.LocalPlayer

local WaterAmbience = SoundUtils.MakeSound("rbxassetid://391263180", script)
WaterAmbience.Looped = true

-- ==========================================
-- Configuration Variables
-- ==========================================
local MAX_HEIGHT = 142
local MIN_HEIGHT = -500
local WATER_LEVEL = 98

-- Background Plane Config
local BACKGROUND_Z_DEPTH = 300
local TOP_WATER_COLOR = Color3.fromHex("#79fffb") -- Light Blue
local BOTTOM_WATER_COLOR = Color3.fromHex("#104287") -- Dark Blue
local DARK_WATER_MULTIPLIER = 0.6 -- How much darker the bottom of the gradient gets (1 = no change, 0 = black)

-- Ambient Lighting Config
local TOP_AMBIENT_COLOR = Color3.fromRGB(255, 255, 255) -- Pure White
local BOTTOM_AMBIENT_COLOR = Color3.fromHex("#969696") -- Dark Gray

-- ==========================================
-- Instance Creation
-- ==========================================
local WaterPlane = Instance.new("Part")
WaterPlane.Name = "WaterBackgroundPlane"
WaterPlane.Size = Vector3.new(2048, 2048, 1)
WaterPlane.Anchored = true
WaterPlane.CanCollide = false
WaterPlane.CastShadow = false
WaterPlane.Material = Enum.Material.Neon

-- UI Creation
local SurfaceGui = Instance.new("SurfaceGui")
SurfaceGui.Name = "SurfaceGui"
SurfaceGui.Face = Enum.NormalId.Front
SurfaceGui.LightInfluence = 1
SurfaceGui.PixelsPerStud = 50
SurfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Frame = Instance.new("Frame")
Frame.Name = "Frame"
Frame.Size = UDim2.new(1, 0, 1, 0)
Frame.BackgroundColor3 = Color3.new(1, 1, 1) -- White so the gradient colors it purely
Frame.BorderSizePixel = 0

local Gradient = Instance.new("UIGradient")
Gradient.Name = "UIGradient"
Gradient.Rotation = 90 -- Top to bottom gradient

-- Parenting UI elements (parenting last is preferred for performance)
Gradient.Parent = Frame
Frame.Parent = SurfaceGui
SurfaceGui.Parent = WaterPlane

local WaterController = {}

WaterController.PlayerInWater = Property.new(false)
WaterController.PlayerDepthPercentage = Property.new(0)

function WaterController.GameStart()
	WaterController.PlayerInWater:Set(false)
	Teleporter.Used:Connect(function(teleporterName)
		if teleporterName == "Ocean" then
			WaterController.PlayerInWater:Set(true)
		elseif teleporterName == "Land" then
			WaterController.PlayerInWater:Set(false)
		end
	end)

	PlayerUtils.ObserveCharacterAdded(Player, function(character, characterTrove)
		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if not rootPart then
			return
		end

		-- ==========================================
		-- Heartbeat (Physics / Logic Loop)
		-- ==========================================
		characterTrove:Connect(RunService.Heartbeat, function()
			local currentY = rootPart.Position.Y

			-- 2. DYNAMIC LIGHTING LOGIC
			local clampedY = math.clamp(currentY, MIN_HEIGHT, MAX_HEIGHT)
			local depthPercentage = (clampedY - MIN_HEIGHT) / (MAX_HEIGHT - MIN_HEIGHT)

			WaterController.PlayerDepthPercentage:Set(depthPercentage)

			Lighting.Ambient = BOTTOM_AMBIENT_COLOR:Lerp(TOP_AMBIENT_COLOR, depthPercentage)
		end)

		-- ==========================================
		-- RenderStepped (Visuals / Camera Loop)
		-- ==========================================
		characterTrove:Connect(RunService.RenderStepped, function()
			local inWater = WaterController.PlayerInWater:Get()

			if inWater then
				if WaterPlane.Parent ~= workspace then
					WaterPlane.Parent = workspace
				end

				-- Match X and Y, lock Z at our target depth
				WaterPlane.CFrame = CFrame.new(rootPart.Position.X, rootPart.Position.Y, BACKGROUND_Z_DEPTH)

				local depthPercentage = WaterController.PlayerDepthPercentage:Get()

				-- Base water color calculation
				local curWaterColor = BOTTOM_WATER_COLOR:Lerp(TOP_WATER_COLOR, math.clamp(depthPercentage, 0, 1))
				local lowerWaterColor =
					BOTTOM_WATER_COLOR:Lerp(TOP_WATER_COLOR, math.clamp(depthPercentage - 0.5, 0, 1))
				WaterPlane.Color = curWaterColor
				Lighting.FogColor = curWaterColor

				-- Create the darker color by multiplying the Value (brightness)
				local darkerWaterColor = lowerWaterColor

				-- Update the ColorSequence using the keypoints you provided
				Gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, curWaterColor),
					ColorSequenceKeypoint.new(0.5, curWaterColor),
					ColorSequenceKeypoint.new(0.7, darkerWaterColor),
					ColorSequenceKeypoint.new(1, darkerWaterColor),
				})
			else
				if WaterPlane.Parent ~= nil then
					WaterPlane.Parent = nil
				end
			end
		end)
	end)
end

return WaterController
