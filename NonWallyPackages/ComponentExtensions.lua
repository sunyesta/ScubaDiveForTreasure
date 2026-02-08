local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local ComponentExtensions = {}

ComponentExtensions.CharacterIsNotAncestor = {
	ShouldConstruct = function(self)
		return not InstanceUtils.FindAncestor(self.Instance, function(inst)
			return inst:FindFirstChild("Humanoid")
		end, false)
	end,
}

ComponentExtensions.ParentedToLocalPlayerCharacter = {
	ShouldConstruct = function(self)
		local player = Players.LocalPlayer
		return player and player.Character and self.Instance.Parent == player.Character
	end,
}

return ComponentExtensions
