local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local CharacterUtils = require(ReplicatedStorage.NonWallyPackages.CharacterUtils)
local Players = game:GetService("Players")

local PlayerUtils = {}
PlayerUtils.__index = PlayerUtils

function PlayerUtils.Wrap(player)
	local self = setmetatable({}, PlayerUtils)
	self.Player = player
	return self
end

function PlayerUtils.ObservePlayerAdded(callback)
	local trove = Trove.new()
	local playerTroves = {}

	local function run(player: Player)
		local playerTrove = trove:Extend()
		playerTroves[player] = playerTrove

		callback(player, playerTrove)
	end

	for _, player in Players:GetChildren() do
		task.spawn(function()
			run(player)
		end)
	end

	trove:Add(Players.PlayerAdded:Connect(function(player)
		run(player)
	end))

	trove:Add(Players.PlayerRemoving:Connect(function(player)
		playerTroves[player]:Clean()
		playerTroves[player] = nil
	end))

	return trove
end

function PlayerUtils.ObserveCharacterAdded(player, callback)
	local characterTrove = Trove.new()
	local function run()
		callback(player.Character, characterTrove)

		characterTrove:Add(player.Character:WaitForChild("Humanoid").Died:Connect(function()
			characterTrove:Clean()
		end))
	end

	if player.Character then
		task.spawn(function()
			run()
		end)
	end

	return player.CharacterAdded:Connect(run)
end

function PlayerUtils.GetPlayerFromPart(part)
	local character = CharacterUtils.GetCharacterFromPart(part)
	return if character then Players:GetPlayerFromCharacter(character) else nil
end

return PlayerUtils
