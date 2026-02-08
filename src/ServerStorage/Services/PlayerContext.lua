local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Signal = require(ReplicatedStorage.Packages.Signal)
local PlayerComm = ServerComm.new(ReplicatedStorage.Comm, "PlayerComm")

return {

	Server = {},
	Client = {
		Comm = PlayerComm,

		-- Properties
		GameVersion = Property.CreateCommProperty(PlayerComm, "GameVersion", ""),
		PlayerLoaded = Property.CreatePlayerCommProperty(PlayerComm, "PlayerLoaded", false),
		Wins = Property.CreatePlayerCommProperty(PlayerComm, "Wins", 0),
	},
}
