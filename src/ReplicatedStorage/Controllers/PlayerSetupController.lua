local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = require(ReplicatedStorage.Packages.Input)
local StarterGui = game:GetService("StarterGui")

task.spawn(function()
	-- pcall(function()
	-- 	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	-- end)
	-- pcall(function()
	-- 	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	-- end)
	-- pcall(function()
	-- 	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	-- end)
end)

local PlayerSetupController = {}

return PlayerSetupController
