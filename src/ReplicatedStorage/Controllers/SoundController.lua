local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Singleton = require(ReplicatedStorage.NonWallyPackages.Singleton)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local MusicMachine = require(ReplicatedStorage.NonWallyPackages.MusicMachine)

-- Require the Playlists module logic so it registers the music with MusicMachine
local Playlists = require(ReplicatedStorage.Common.Modules.Playlists)

local SoundController = {}

-- Public volume properties (0-1)
SoundController.SoundVolume = Property.new(0.8)
SoundController.MusicVolume = Property.new(0)

-- Uncommented this so the property actually controls the music volume
SoundController.MusicVolume:Observe(function(musicVolume)
	MusicMachine.GlobalVolume = musicVolume
end)

return SoundController
