local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

-- LayeredSong
-- Wraps multiple Sound instances to be played/controlled as a single unit.
-- Useful for vertical remixing or stems (e.g., Drums, Bass, Melody playing together).

local LayeredSong = {}
local LayeredSongProto = {}

-- Marker to identify this object in Playlist
LayeredSongProto.IsLayeredSong = true

function LayeredSong.new(layers)
	local self = newProxy(layers)
	return self
end

function newProxy(layers)
	local proxy = {}

	-- Internal Data
	local data = {
		_trove = Trove.new(),
		_layers = {},
		_baseVolumes = {},
		_volume = 1,
		_isPlaying = false,
	}

	-- Setup Layers
	if layers then
		for _, sound in ipairs(layers) do
			if typeof(sound) == "Instance" and sound:IsA("Sound") then
				table.insert(data._layers, sound)
				-- Store the original volume ratio relative to 1
				-- (We assume the sound provided has the desired 'mix' volume)
				table.insert(data._baseVolumes, sound.Volume)
			end
		end
	end

	-- Cleanup
	function data:Destroy()
		self._trove:Destroy()
	end

	-- Metatable to emulate Sound API
	local mt = {
		__index = function(t, k)
			-- 1. Check Prototype Methods
			if LayeredSongProto[k] then
				return LayeredSongProto[k]
			end

			-- 2. Access Internal Data for methods to use
			if k == "_data" then
				return data
			end

			-- 3. Emulate Sound Properties
			if k == "TimeLength" then
				local maxLen = 0
				for _, s in ipairs(data._layers) do
					if s.TimeLength > maxLen then
						maxLen = s.TimeLength
					end
				end
				return maxLen
			elseif k == "TimePosition" then
				-- We assume layers are synced, return first valid
				local s = data._layers[1]
				return s and s.TimePosition or 0
			elseif k == "IsPlaying" then
				-- If ANY layer is playing, we consider it playing
				for _, s in ipairs(data._layers) do
					if s.IsPlaying then
						return true
					end
				end
				return false
			elseif k == "Volume" then
				return data._volume
			end

			return nil
		end,

		__newindex = function(t, k, v)
			if k == "Volume" then
				data._volume = v
				-- Update all layers relative to their base mix
				for i, s in ipairs(data._layers) do
					local base = data._baseVolumes[i] or 1
					s.Volume = v * base
				end
			elseif k == "TimePosition" then
				for _, s in ipairs(data._layers) do
					s.TimePosition = v
				end
			elseif k == "Parent" then
				-- When Playlist sets Parent, we set it for all sounds
				for _, s in ipairs(data._layers) do
					s.Parent = v
				end
			elseif k == "Looped" then
				for _, s in ipairs(data._layers) do
					s.Looped = v
				end
			else
				-- Allow setting custom fields on the proxy table?
				-- For now, we just ignore or could strict error.
			end
		end,

		__tostring = function()
			return "LayeredSong"
		end,
	}

	setmetatable(proxy, mt)

	-- Ensure Trove cleans up the proxy data if needed
	data._trove:Add(function()
		for _, s in ipairs(data._layers) do
			s:Destroy()
		end
		data._layers = {}
	end)

	return proxy
end

-------------------------------------------------------------------------------
-- PROTOTYPE METHODS
-------------------------------------------------------------------------------

function LayeredSongProto:Clone()
	local data = self._data
	local newLayers = {}

	for _, s in ipairs(data._layers) do
		local clone = s:Clone()
		table.insert(newLayers, clone)
	end

	-- Create new instance
	return LayeredSong.new(newLayers)
end

function LayeredSongProto:Play()
	local data = self._data
	data._isPlaying = true
	for _, s in ipairs(data._layers) do
		s:Play()
	end
end

function LayeredSongProto:Stop()
	local data = self._data
	data._isPlaying = false
	for _, s in ipairs(data._layers) do
		s:Stop()
	end
end

function LayeredSongProto:Pause()
	local data = self._data
	data._isPlaying = false
	for _, s in ipairs(data._layers) do
		s:Pause()
	end
end

function LayeredSongProto:Resume()
	local data = self._data
	data._isPlaying = true
	for _, s in ipairs(data._layers) do
		s:Resume()
	end
end

function LayeredSongProto:Destroy()
	self._data:Destroy()
end

return LayeredSong
