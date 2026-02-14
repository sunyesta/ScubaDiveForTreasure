local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local Trove = require(ReplicatedStorage.Packages.Trove)

local WoodChips = GetAssetByName("WoodChips")

local SpawnVisualEffect = {}

function SpawnVisualEffect.WoodChips(position: Vector3, color: Color3)
	local trove = Trove.new()

	local ParticleEmmiterPart = trove:Add(WoodChips:Clone())
	ParticleEmmiterPart.Parent = workspace
	ParticleEmmiterPart.Position = position
	ParticleEmmiterPart.ParticleEmmiter.Color = ColorSequence.new(color)

	task.delay(0.1, function()
		ParticleEmmiterPart.ParticleEmmiter.Enabled = false
		task.wait(1)
		ParticleEmmiterPart:Destroy()
	end)
end

-- spawns electricity effect on part until trove is cleaned
function SpawnVisualEffect.Electricity(part)
	local effectTrove = Trove.new()

	local emitter = effectTrove:Add(Instance.new("ParticleEmitter"))
	emitter.Name = "ElectricityEmitter"
	emitter.Texture = "rbxassetid://178024715"
	emitter.Parent = part

	-- Visual Properties for Electricity
	emitter.LightEmission = 1 -- Makes it glow/additive blending
	emitter.Color = ColorSequence.new(Color3.fromRGB(117, 230, 255)) -- Electric Cyan
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3), -- Start large
		NumberSequenceKeypoint.new(1, 3), -- Stay large
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1), -- Quick fade out at the very end
	})

	-- Behavior Properties
	emitter.Lifetime = NumberRange.new(0.05, 0.15) -- Very short life for "flicker" effect
	emitter.Rate = 30 -- Frequent spawning
	emitter.Rotation = NumberRange.new(0, 360) -- Random initial rotation
	emitter.RotSpeed = NumberRange.new(0) -- No rotation over time (snappy)
	emitter.Speed = NumberRange.new(0) -- Stay stationary on the attachment
	emitter.LockedToPart = true -- If the part moves, the electricity follows perfectly
	emitter.ZOffset = 1 -- Render slightly in front of the part

	return effectTrove
end

return SpawnVisualEffect
