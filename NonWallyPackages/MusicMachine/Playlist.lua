local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

-------------------------------------------------------------------------------
-- PLAYLIST
-------------------------------------------------------------------------------
-- Manages a sequence of sounds. Handles cloning, looping, and volume setting.
local Playlist = {}
Playlist.__index = Playlist

function Playlist.new(name, sourceSounds, priority)
	local self = setmetatable({}, Playlist)

	self.Name = name or "Playlist"
	self.Priority = priority or 0

	-- Internal State
	self._trove = Trove.new()
	self._sourceSounds = sourceSounds or {} -- List of Sound Instances OR LayeredSongs
	self._activeSounds = {} -- List of locally cloned playing instances

	self._currentIndex = 1
	self._currentSound = nil
	self._isPlaying = false
	self._isInitialized = false

	return self
end

function Playlist:InitSounds()
	if self._isInitialized then
		return
	end
	self._isInitialized = true

	self._activeSounds = {}

	for _, originalItem in ipairs(self._sourceSounds) do
		local clone = nil

		-- Case 1: Standard Roblox Sound
		if typeof(originalItem) == "Instance" and originalItem:IsA("Sound") then
			clone = originalItem:Clone()
			clone.Parent = script -- Run inside the script

		-- Case 2: LayeredSong
		elseif typeof(originalItem) == "table" and originalItem.IsLayeredSong then
			clone = originalItem:Clone()
			-- LayeredSong handles the parenting of its internal sounds via this setter
			clone.Parent = script
		end

		if clone then
			self._trove:Add(clone)
			table.insert(self._activeSounds, clone)
		end
	end
end

function Playlist:Play()
	if self._isPlaying then
		return
	end
	self._isPlaying = true

	if not self._isInitialized then
		self:InitSounds()
	end

	-- Resume or Start
	if #self._activeSounds > 0 then
		if not self._currentSound then
			self._currentIndex = 1
			self:_PlayCurrent()
		else
			self._currentSound:Resume()
		end
	end
end

function Playlist:Stop()
	if not self._isPlaying then
		return
	end
	self._isPlaying = false

	if self._currentSound then
		self._currentSound:Pause() -- Pause so we can resume later? Or Stop to reset?
		-- If you want full reset on stop:
		-- self._currentSound:Stop()
		-- self._currentSound = nil
	end
end

function Playlist:_PlayCurrent()
	-- Stop others
	for _, s in ipairs(self._activeSounds) do
		s:Stop()
	end

	local sound = self._activeSounds[self._currentIndex]
	if sound then
		self._currentSound = sound
		sound.TimePosition = 0
		sound:Play()
	end
end

function Playlist:_Advance()
	if #self._activeSounds == 0 then
		return
	end

	self._currentIndex = self._currentIndex + 1
	if self._currentIndex > #self._activeSounds then
		self._currentIndex = 1
	end

	self:_PlayCurrent()
end

function Playlist:Update(dt, volume)
	-- Ensure we are in play state
	if not self._isPlaying then
		self:Play()
	end

	if #self._activeSounds == 0 then
		return
	end

	local sound = self._currentSound

	-- Check if track finished
	if sound then
		-- Robust check for ending: IsPlaying becomes false OR TimePosition is at end
		-- Note: IsPlaying can be flaky if the sound hasn't loaded, so we also check TimeLength > 0
		if not sound.IsPlaying and sound.TimeLength > 0 and sound.TimePosition >= (sound.TimeLength - 0.1) then
			self:_Advance()
		elseif not sound.IsPlaying and sound.TimePosition == 0 then
			-- Case: It hasn't started yet or stopped unexpectedly
			sound:Play()
		end

		sound.Volume = volume
	else
		-- No sound selected but we have sounds
		self:_PlayCurrent()
	end
end

function Playlist:Destroy()
	self:Stop()
	self._trove:Destroy()
end

return Playlist
