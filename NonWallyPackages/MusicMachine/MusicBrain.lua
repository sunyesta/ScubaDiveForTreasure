local Playlist = require(script.Parent.Playlist)

-------------------------------------------------------------------------------
-- MUSIC BRAIN (The Manager)
-------------------------------------------------------------------------------
local MusicBrain = {}
MusicBrain.__index = MusicBrain

function MusicBrain.new()
	local self = setmetatable({}, MusicBrain)

	self.ActivePlaylist = nil
	self.RegisteredPlaylists = {}

	-- Configuration
	self.DefaultBlendTime = 2.0 -- Seconds to crossfade

	-- Blending Internals
	self.IsBlending = false
	self.BlendTimer = 0
	self.BlendDuration = 0

	self.OutgoingPlaylist = nil

	return self
end

function MusicBrain:Register(playlist)
	if not playlist then
		return
	end

	-- Avoid duplicates
	for _, p in ipairs(self.RegisteredPlaylists) do
		if p == playlist then
			return
		end
	end

	table.insert(self.RegisteredPlaylists, playlist)
	self:RefreshPriority()
end

function MusicBrain:Unregister(playlist)
	for i, p in ipairs(self.RegisteredPlaylists) do
		if p == playlist then
			table.remove(self.RegisteredPlaylists, i)
			break
		end
	end
	self:RefreshPriority()
end

function MusicBrain:RefreshPriority()
	local highestPrio = -math.huge
	local topPlaylist = nil

	for _, playlist in ipairs(self.RegisteredPlaylists) do
		if playlist.Priority > highestPrio then
			highestPrio = playlist.Priority
			topPlaylist = playlist
		end
	end

	if topPlaylist ~= self.ActivePlaylist then
		self:CutTo(topPlaylist)
	end
end

function MusicBrain:CutTo(newPlaylist)
	if self.ActivePlaylist == newPlaylist then
		return
	end

	-- Set current active as outgoing to begin fade out
	if self.ActivePlaylist then
		self.OutgoingPlaylist = self.ActivePlaylist
		self.IsBlending = true
		self.BlendTimer = 0
		self.BlendDuration = self.DefaultBlendTime
	else
		-- First playlist, no blend needed
		self.IsBlending = false
	end

	self.ActivePlaylist = newPlaylist
end

function MusicBrain:Update(dt, globalVolume)
	-- 1. Handle Active Playlist (Fade In / Sustain)
	if self.ActivePlaylist then
		local targetVolume = globalVolume

		if self.IsBlending then
			self.BlendTimer = self.BlendTimer + dt
			local t = math.clamp(self.BlendTimer / self.BlendDuration, 0, 1)

			-- Smoothstep for nicer audio fade
			local smoothT = t * t * (3 - 2 * t)
			targetVolume = globalVolume * smoothT

			if t >= 1 then
				self.IsBlending = false
				self.OutgoingPlaylist = nil
			end
		end

		-- Pump the playlist logic
		self.ActivePlaylist:Update(dt, targetVolume)
	end

	-- 2. Handle Outgoing Playlist (Fade Out)
	if self.OutgoingPlaylist then
		if self.IsBlending then
			local t = math.clamp(self.BlendTimer / self.BlendDuration, 0, 1)
			local smoothT = t * t * (3 - 2 * t)

			local fadeOutVolume = globalVolume * (1 - smoothT)
			self.OutgoingPlaylist:Update(dt, fadeOutVolume)
		else
			-- Ensure it is fully stopped if blending is done
			self.OutgoingPlaylist:Stop()
			self.OutgoingPlaylist = nil
		end
	end

	-- 3. Ensure unregistered or inactive playlists are stopped
	-- (Optimization: You might want to track this more efficiently if you have hundreds of playlists)
	for _, playlist in ipairs(self.RegisteredPlaylists) do
		if playlist ~= self.ActivePlaylist and playlist ~= self.OutgoingPlaylist then
			playlist:Stop()
		end
	end
end

function MusicBrain:Destroy()
	for _, playlist in ipairs(self.RegisteredPlaylists) do
		playlist:Destroy()
	end
	self.RegisteredPlaylists = {}
end

return MusicBrain
