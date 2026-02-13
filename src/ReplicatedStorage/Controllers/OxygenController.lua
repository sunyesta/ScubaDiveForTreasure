local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local Zone = require(ReplicatedStorage.NonWallyPackages.Zone)

--Instances
local Player = Players.LocalPlayer
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

-- Constants
local O2_DEPLETE_SPEED = 1 -- Amount of Oxygen lost per second
local O2_REGEN_SPEED = 1000 -- Amount of Oxygen gained per second

local OxygenController = {}

-- Initialize Properties
local MaxOxygen = Property.BindToCommProperty(PlayerComm.MaxOxygen)
local Oxygen = Property.new(MaxOxygen:Get())
OxygenController.Oxygen = Oxygen

function OxygenController.GameStart()
	-- 1. Gather all parts tagged "Water" to create our zone
	local waterParts = CollectionService:GetTagged("Water")

	-- Safety check: ensure there is at least one water part
	if #waterParts == 0 then
		warn("OxygenController: No parts tagged 'Water' found!")
		return
	end

	-- 2. Create the Zone from the list of water parts
	local waterZone = Zone.new(waterParts)

	-- Optional: optimize zone accuracy if needed (High is default)
	-- waterZone.accuracy = Zone.enum.Accuracy.High

	-- 3. Start a loop to check the player's status every frame
	RunService.Heartbeat:Connect(function(dt)
		local character = Player.Character
		if not character then
			return
		end

		local head = character:FindFirstChild("Head")
		if not head then
			return
		end

		-- 4. Check if the SPECIFIC part (Head) is within the water zone
		-- findPart returns true if the part is intersecting the zone
		local isHeadInWater = waterZone:findPart(head)

		local currentOxygen = Oxygen:Get()
		local maxO2 = MaxOxygen:Get()

		if isHeadInWater then
			-- Deplete Oxygen
			if currentOxygen > 0 then
				local change = O2_DEPLETE_SPEED * dt
				local newOxygen = math.max(0, currentOxygen - change)
				Oxygen:Set(newOxygen)
			end

			if currentOxygen == 0 then
				OxygenController.Kill()
			end
		else
			-- Regenerate Oxygen (Optional: remove this else block if you don't want regen)
			if currentOxygen < maxO2 then
				local change = O2_REGEN_SPEED * dt
				local newOxygen = math.min(maxO2, currentOxygen + change)
				Oxygen:Set(newOxygen)
			end
		end
	end)
end

function OxygenController.Kill()
	local character = Player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		isProcessingKill = true

		-- Setting health to 0 on the client will replicate to the server
		-- for the purpose of killing the character.
		humanoid.Health = 0

		-- Reset Oxygen immediately so they don't die again the moment they respawn
		Oxygen:Set(MaxOxygen:Get())

		-- Brief delay to allow the character to reset before resuming oxygen logic
		task.delay(1, function()
			isProcessingKill = false
		end)
	end
end
return OxygenController
