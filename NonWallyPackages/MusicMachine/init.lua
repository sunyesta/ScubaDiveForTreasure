local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Trove = require(ReplicatedStorage.Packages.Trove)
local MusicBrain = require(script.MusicBrain)
local Playlist = require(script.Playlist)
local LayeredSong = require(script.LayeredSong)

-- MusicMachine
-- A priority-based sound controller inspired by Cinemachine.
-- Handles blending between Playlists based on priority.

local MusicMachine = {}
MusicMachine.__index = MusicMachine

-------------------------------------------------------------------------------
-- MODULE EXPORTS
-------------------------------------------------------------------------------
MusicMachine.Brain = MusicBrain.new()
MusicMachine.Playlist = Playlist
MusicMachine.LayeredSong = LayeredSong

-- Global Volume Multiplier (0-1)
MusicMachine.GlobalVolume = 1

MusicMachine._trove = Trove.new()

-- Auto-start the brain loop
-- We use Heartbeat because sound volume updates don't need RenderStep precision
MusicMachine._trove:Connect(RunService.Heartbeat, function(dt)
	MusicMachine.Brain:Update(dt, MusicMachine.GlobalVolume)
end)

function MusicMachine:Destroy()
	self._trove:Destroy()
	self.Brain:Destroy()
end

return MusicMachine
