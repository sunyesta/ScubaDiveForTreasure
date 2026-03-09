local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local CreateProximityPrompt = require(ReplicatedStorage.Common.Modules.GameUtils.CreateProximityPrompt)
local OxygenController = require(ReplicatedStorage.Common.Controllers.OxygenController)
local SoundUtils = require(ReplicatedStorage.NonWallyPackages.SoundUtils)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm

local Player = Players.LocalPlayer

-- ==========================================
-- CONFIGURATION
-- ==========================================
local Config = {
	OxygenReward = 100,
	InflateSoundId = "rbxassetid://139991012767396",

	Bubble = {
		SpawnRateMin = 3, -- Minimum time between bubbles (seconds)
		SpawnRateMax = 5, -- Maximum time between bubbles (seconds)
		ScaleMin = 0.6, -- Minimum size multiplier
		ScaleMax = 1.4, -- Maximum size multiplier
		InflateDuration = 0.4, -- How fast the bubble pops out (seconds)
		FloatDurationMin = 2.5, -- Minimum time the bubble floats before popping (seconds)
		FloatDurationMax = 4.5, -- Maximum time the bubble floats before popping (seconds)
		DriftMax = 2.0, -- Maximum X and Z wobble distance (studs)
		FloatHeightMin = 15.0, -- Minimum vertical distance traveled (studs)
		FloatHeightMax = 25.0, -- Maximum vertical distance traveled (studs)
	},
}
-- ==========================================

local OxygenCoral = Component.new({
	Tag = "OxygenCoral",
	Ancestors = { Workspace },
})

function OxygenCoral:Construct()
	self._Trove = Trove.new()
	self._Comm = ClientComm.new(self.Instance, true, "_Comm1"):BuildObject()
end

function OxygenCoral:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))

	self._Trove:Add(partStreamable:Observe(function(rootPart: BasePart, loadedTrove)
		if rootPart then
			self:Loaded(rootPart, loadedTrove)
		end
	end))
end

function OxygenCoral:Stop()
	self._Trove:Clean()
end

function OxygenCoral:Loaded(rootPart: BasePart, trove)
	-- when the collect prompt is triggered, destroy self and add oxygen
	local CollectPrompt: ProximityPrompt = trove:Add(CreateProximityPrompt(rootPart, "Collect"))

	trove:Add(CollectPrompt.Triggered:Connect(function()
		-- OxygenController.Oxygen:Update(function(oxygen: number)
		-- 	return oxygen + Config.OxygenReward
		-- end)

		-- self.Instance:Destroy()
		self._Comm:Harvest()
	end))

	local BubbleTemplate: BasePart = self.Instance:WaitForChild("Bubble")
	local BubbleDecal: Decal = BubbleTemplate:WaitForChild("Decal")

	-- Hide the template itself and its decal
	BubbleTemplate.Transparency = 1
	BubbleDecal.Transparency = 1

	local InflateSound = trove:Add(SoundUtils.MakeSound(Config.InflateSoundId, rootPart))
	local BubbleStartPos: Vector3 = BubbleTemplate.Position
	local BaseBubbleSize: Vector3 = BubbleTemplate.Size

	-- Create a random number generator for smoother decimal math
	local rng = Random.new()

	-- Create a thread to handle continuous bubble generation
	local bubbleThread = task.spawn(function()
		while true do
			-- Jitter the rate using the config min and max
			task.wait(rng:NextNumber(Config.Bubble.SpawnRateMin, Config.Bubble.SpawnRateMax))

			-- Play the inflation sound
			-- InflateSound:Play()

			-- 1. Create and configure the new bubble (Parenting last for performance)
			local newBubble = BubbleTemplate:Clone()
			local newDecal = newBubble.Decal

			newDecal.Transparency = 0 -- Make the new bubble's decal fully visible
			newBubble.Size = Vector3.new(0, 0, 0) -- Start invisible/tiny
			newBubble.Position = BubbleStartPos

			-- 2. Jitter the size based on config multipliers
			local scaleMultiplier = rng:NextNumber(Config.Bubble.ScaleMin, Config.Bubble.ScaleMax)
			local targetSize = BaseBubbleSize * scaleMultiplier

			-- 3. Setup Inflate Animation (Pops out quickly with a slight overshoot)
			local inflateInfo =
				TweenInfo.new(Config.Bubble.InflateDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local inflateTween = TweenService:Create(newBubble, inflateInfo, {
				Size = targetSize,
			})

			-- 4. Setup Float Animation (Drifts up and fades out)
			local floatDuration = rng:NextNumber(Config.Bubble.FloatDurationMin, Config.Bubble.FloatDurationMax)
			local driftX = rng:NextNumber(-Config.Bubble.DriftMax, Config.Bubble.DriftMax)
			local driftZ = rng:NextNumber(-Config.Bubble.DriftMax, Config.Bubble.DriftMax)
			local floatHeight = rng:NextNumber(Config.Bubble.FloatHeightMin, Config.Bubble.FloatHeightMax)

			local targetPosition = BubbleStartPos + Vector3.new(driftX, floatHeight, driftZ)

			local floatInfo = TweenInfo.new(floatDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

			-- Tween for the part's position
			local floatTween = TweenService:Create(newBubble, floatInfo, {
				Position = targetPosition,
			})

			-- Tween for the decal's transparency
			local fadeTween = TweenService:Create(newDecal, floatInfo, {
				Transparency = 1,
			})

			-- Parent the bubble to the workspace/rootPart right before animating
			newBubble.Parent = rootPart

			-- 5. Play Animations in Sequence
			inflateTween:Play()

			-- Once inflated, start floating and fading
			inflateTween.Completed:Connect(function()
				floatTween:Play()
				fadeTween:Play()
			end)

			-- Clean up the bubble instance once it fully floats and fades away
			floatTween.Completed:Connect(function()
				newBubble:Destroy()
			end)
		end
	end)

	-- Add the thread to the trove so it is automatically cancelled when collected
	trove:Add(bubbleThread)
end

return OxygenCoral
