local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local SoundPart = {}
SoundPart.__index = SoundPart

function SoundPart.new(soundID, volume)
	local self = setmetatable(SoundPart, {})
	self._Trove = Trove.new()

	local part = self._Trove:Add(Instance.new("Part"))
	part.Size = Vector3.new(1, 1, 1)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = workspace

	local sound = self._Trove:Add(Instance.new("Sound"))
	sound.SoundId = soundID
	sound.Volume = volume or 1
	sound.Parent = part

	self._Part = part
	self.Sound = sound

	return self
end

function SoundPart:PlayAt(position)
	self._Part.Position = position
	self.Sound:Play()
end

function SoundPart:PlayAtThenDestroy(position)
	self._Part.Position = position
	self.Sound:Play()

	-- Wait for the sound to finish, then clean up everything
	self.Sound.Ended:Once(function()
		self:Destroy()
	end)
end
function SoundPart:Destroy()
	self._Trove:Destroy()
end

return SoundPart
