local ServerStorage = game:GetService("ServerStorage")
local PlayerContext = require(ServerStorage.Source.Services.PlayerContext)
local VersionService = {}

-- game.PlaceVersion returns the integer version of the specific place (e.g., 152)
-- It updates automatically when you publish to Roblox.
VersionService.Version = game.PlaceVersion

-- Optional: You can define a Major/Minor version manually if you want "v1.2.152"
local MAJOR_VERSION = 1
local MINOR_VERSION = 0

-- Function to return the raw integer version
function VersionService.GetVersion()
	return VersionService.Version
end

-- Function to return a formatted string (e.g., "v1.0.45")
function VersionService.GetFormattedVersion()
	return string.format("v%d.%d.%d", MAJOR_VERSION, MINOR_VERSION, VersionService.Version)
end

-- Useful for debugging or printing to server console on startup
function VersionService.PrintVersion()
	print("Game Version: " .. VersionService.GetFormattedVersion())
end

function VersionService.GameStart()
	PlayerContext.Client.GameVersion:Set(VersionService.GetFormattedVersion())
end

return VersionService
