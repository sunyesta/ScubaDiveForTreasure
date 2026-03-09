local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local OxygenController = require(ReplicatedStorage.Common.Controllers.OxygenController)
local SoundPart = require(ReplicatedStorage.NonWallyPackages.SoundPart)

local Player = Players.LocalPlayer

local OxygenCoralTool = Component.new({
	Tag = "OxygenCoralTool",
	Ancestors = { Workspace },
})

function OxygenCoralTool:Construct()
	self._Trove = Trove.new()
	self.EatSound = SoundPart.new("rbxassetid://6912105138")
	self._Trove:Add(function()
		task.wait(10)
		self.EatSound:Destroy()
	end)
end

function OxygenCoralTool:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "Handle"))

	self._Trove:Add(partStreamable:Observe(function(rootPart, loadedTrove)
		if rootPart then
			self:Loaded(rootPart, loadedTrove)
		end
	end))
end

function OxygenCoralTool:Stop()
	self._Trove:Clean()
end

function OxygenCoralTool:Loaded(handle, trove)
	local tool: Tool = self.Instance
	local used = false
	trove:Add(tool.Activated:Connect(function()
		if used then
			return
		end
		used = true
		local player = Players:GetPlayerFromCharacter(tool.Parent)

		if player == Player then
			OxygenController.Oxygen:Update(function(oxygen)
				return oxygen + 100
			end)
		end
		self.EatSound:PlayAtThenDestroy(self.Instance.PrimaryPart.Position)
		self.Instance:Destroy()
	end))
end

return OxygenCoralTool
