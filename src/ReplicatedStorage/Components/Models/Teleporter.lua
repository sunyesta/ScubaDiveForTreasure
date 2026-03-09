local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Player = Players.LocalPlayer

-- Hash table to store exit models
local ExitModels = {}

-- Helper function to add an exit model to our dictionary
local function onExitModelAdded(model: Model)
	local teleporterName = model:GetAttribute("TeleporterName")
	if teleporterName then
		ExitModels[teleporterName] = model
	end
end

-- Helper function to remove an exit model from our dictionary if it gets destroyed/untagged
local function onExitModelRemoved(model: Model)
	local teleporterName = model:GetAttribute("TeleporterName")
	if teleporterName and ExitModels[teleporterName] == model then
		ExitModels[teleporterName] = nil
	end
end

-- 1. Grab any exit models that already exist in the Workspace
for _, model in CollectionService:GetTagged("TeleporterExit") do
	onExitModelAdded(model)
end

-- 2. Listen for any future exit models that stream in or are created dynamically
CollectionService:GetInstanceAddedSignal("TeleporterExit"):Connect(onExitModelAdded)
CollectionService:GetInstanceRemovedSignal("TeleporterExit"):Connect(onExitModelRemoved)

local Teleporter = Component.new({
	Tag = "Teleporter",
	Ancestors = { Workspace },
})
Teleporter.Used = Signal.new() -- (teleporterName)

function Teleporter:Construct()
	self._Trove = Trove.new()
	self._isTeleporting = false -- Debounce to prevent multiple teleport fires
end

function Teleporter:Start()
	-- Cast self.Instance as a Model instead of a BasePart
	local model: Model = self.Instance

	-- Safely yield for the RootPart inside the model
	local rootPart: BasePart = model:WaitForChild("RootPart")

	-- Get the attribute from the Model.
	-- (Note: If your attribute is on the RootPart, change this to rootPart:GetAttribute)
	local teleporterName = model:GetAttribute("TeleporterName")

	-- Connect to the Touched event on the RootPart and track it with Trove
	self._Trove:Connect(rootPart.Touched, function(hit: BasePart)
		-- 1. Check debounce
		if self._isTeleporting then
			return
		end

		-- 2. Verify we hit a character
		local character = hit.Parent
		if not character then
			return
		end

		-- 3. Verify it's the LocalPlayer's character (Client-sided check)
		if character ~= Player.Character then
			return
		end

		local humanoid = character:FindFirstChild("Humanoid")
		local charRootPart = character:FindFirstChild("HumanoidRootPart")

		-- 4. Ensure the character is alive and valid
		if humanoid and humanoid.Health > 0 and charRootPart then
			local exitModel: Model = ExitModels[teleporterName]

			if teleporterName and exitModel then
				-- Try to find the physical RootPart within the exit model
				local exitPart = exitModel:FindFirstChild("RootPart")

				if exitPart and exitPart:IsA("BasePart") then
					self._isTeleporting = true

					-- Calculate the new CFrame: Top of the exit part
					-- We add half the exit part's height, plus ~3 studs to account for the player's height (R6/R15 safe)
					local yOffset = (exitPart.Size.Y / 2) + 3
					local targetCFrame = exitPart.CFrame * CFrame.new(0, yOffset, 0)

					-- Use PivotTo for optimized and safe character movement
					character:PivotTo(targetCFrame)

					Teleporter.Used:Fire(teleporterName)

					-- Short cooldown before this specific teleporter can be used by this client again
					task.wait(0.5)
					self._isTeleporting = false
				else
					warn(
						"Teleporter failed: ExitModel found for '"
							.. tostring(teleporterName)
							.. "' but missing 'RootPart'"
					)
				end
			else
				warn("Teleporter failed: No ExitModel found for TeleporterName '" .. tostring(teleporterName) .. "'")
			end
		end
	end)
end

function Teleporter:Stop()
	-- Automatically cleans up our .Touched event connection
	self._Trove:Clean()
end

return Teleporter
