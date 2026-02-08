local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicMachine = require(ReplicatedStorage.NonWallyPackages.MusicMachine)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local WaitUtils = require(ReplicatedStorage.NonWallyPackages.WaitUtils)

-- wait for all sounds to load
local SoundsFolder = ReplicatedStorage.Assets:WaitForChild("Sounds")
WaitUtils.WaitForDescendantsCount(SoundsFolder, SoundsFolder:GetAttribute("DescendantCount")):expect()

-- 1. Define Playlists
local ExamplePlaylist = MusicMachine.Playlist.new("Intense", { GetAssetByName("IntenseHawaiianMusic") }, 0)
MusicMachine.Brain:Register(ExamplePlaylist)

MusicMachine.Brain:RefreshPriority()

local Playlists = {}

Playlists.Example = ExamplePlaylist

return Playlists
