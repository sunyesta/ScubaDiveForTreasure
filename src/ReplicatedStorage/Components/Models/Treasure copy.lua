local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Input = require(ReplicatedStorage.Packages.Input)
local TreasureUtils = require(ReplicatedStorage.Common.Modules.ComponentUtils.TreasureUtils)

local Player = Players.LocalPlayer
local Keyboard = Input.Keyboard.new()

local TreasureClient = Component.new({
	Tag = "TreasureOLD",
	Ancestors = { Workspace },
})

function TreasureClient:Construct()
	self._Trove = Trove.new()
	self._Comm = ClientComm.new(self.Instance, true, "_Comm"):BuildObject()
	self._GrabProximityPrompt = self.Instance:WaitForChild("GrabProximityPrompt")
end

function TreasureClient:Start()
	-- Zero Lag Grab: Attempt to visually attach immediately when triggered
	self._Trove:Add(self._GrabProximityPrompt.Triggered:Connect(function()
		local character = Player.Character
		if character then
			-- Create local weld immediately
			local localWeld = TreasureUtils.Attach(self.Instance, character)
			local rootPart = self.Instance.PrimaryPart

			-- CLEANUP STRATEGY:
			-- Monitor the part for the arrival of the Server's weld.
			-- Once the server weld (replicated) arrives, destroy our local visual weld.
			if rootPart and localWeld then
				local connection
				connection = rootPart.ChildAdded:Connect(function(child)
					if child.Name == TreasureUtils.WELD_NAME and child ~= localWeld and child:IsA("WeldConstraint") then
						-- Server weld arrived! Clean up local one to prevent double physics constraints.
						if localWeld.Parent then
							localWeld:Destroy()
						end
						connection:Disconnect()
					end
				end)

				-- Ensure we disconnect this listener if the component stops
				self._Trove:Add(connection)
			end
		end
	end))

	self._Trove:Add(Keyboard.KeyUp:Connect(function(key)
		if key == Enum.KeyCode.Backspace then
			-- Zero Lag Drop: Disable the weld locally first.
			TreasureUtils.Detach(self.Instance)

			-- Tell server to handle the official drop logic
			self._Comm:Drop()
		end
	end))
end

function TreasureClient:Stop()
	self._Trove:Clean()
end

return TreasureClient
