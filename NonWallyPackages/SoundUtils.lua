local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local SoundUtils = {}

function SoundUtils.MakeSound(soundID, parent, volume)
	local sound = Instance.new("Sound")
	sound.Parent = parent or script
	sound.SoundId = soundID
	sound.Volume = volume or 1

	return sound
end

function SoundUtils.PlaySoundFromID(soundID, parent)
	local trove = Trove.new()
	local sound: Sound = trove:Add(SoundUtils.MakeSound(soundID, parent))
	sound:Play()

	trove:Add(sound.Ended:Connect(function()
		trove:Clean()
	end))

	return trove
end

return SoundUtils
