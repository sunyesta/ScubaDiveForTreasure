local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local TreasureUtils = require(ReplicatedStorage.Common.Modules.ComponentUtils.TreasureUtils)
local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)

local VELOCITY_THRESHOLD = 0.1
local SEED_RANGE = 1000000

local TreasureServer = Component.new({
	Tag = "Treasure",
	Ancestors = { Workspace },
})

function TreasureServer:Construct()
	assert(self.Instance.PrimaryPart, "No Primary part found for Treasure")

	self._Trove = Trove.new()

	-- Initialize sub-troves for state management
	self._HoldTrove = self._Trove:Extend()
	self._ReserveTrove = self._Trove:Extend()

	self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm"))

	self._HoldingPlayer = Property.new(nil)
	self._ReservedBy = Property.new(nil)
	self._LockedPlayer = Property.CreateCommProperty(self._Comm, "LockedPlayer", nil)

	-- RunService.Stepped:Connect(function(time, deltaTime)
	-- 	if self.Instance.PrimaryPart.Anchored == false then
	-- 		print(self.Instance.PrimaryPart:GetNetworkOwner())
	-- 	end
	-- end)

	self._LockedPlayer:Observe(function(lockedPlayer)
		print("LockedPlayer changed to:", lockedPlayer)
	end)

	-- Synced attribute for clients to know state
	self._AttachedPlayerName = Property.BindToAttribute(self.Instance, "_AttachedPlayerName", nil)

	self.PlaneOrigin = self.Instance.PrimaryPart.Position
	self.PlaneNormal = self.Instance:GetAttribute("PlaneNormal") or Vector3.new(0, 0, -1)

	World2DUtils.ConstrainToPlane(self.Instance.PrimaryPart, self.PlaneOrigin, self.PlaneNormal)

	local itemSeed = math.random(1, SEED_RANGE)
	self.Instance:SetAttribute("RandomSeed", itemSeed)
end

function TreasureServer:Start()
	-- Bind Grab Function
	self._Comm:BindFunction("Grab", function(player)
		return self:Grab(player)
	end)

	-- Bind Drop Function
	self._Comm:BindFunction("Drop", function(player)
		if player == self._HoldingPlayer:Get() then
			self:Drop(player)
			return true
		end
		return false
	end)

	self._Comm:BindFunction("Claim", function(player)
		self:ClaimFor(player)
	end)
end

function TreasureServer:Stop()
	self._Trove:Clean()
end

function TreasureServer:Grab(player)
	-- Guard clause: Validate character exists and item isn't already held
	if not player.Character or not player.Character.Parent then
		return false
	end

	-- Check if held
	if self._HoldingPlayer:Get() ~= nil then
		return false
	end

	-- Check if locked/reserved by someone else
	local reserved = self._ReservedBy:Get()
	if reserved and reserved ~= player then
		return false
	end

	local rootPart = self.Instance.PrimaryPart
	if not rootPart then
		return false
	end

	-- 1. Set State
	self._HoldingPlayer:Set(player)
	self._AttachedPlayerName:Set(player.Name)

	-- Clear any existing reservation logic immediately
	self._ReserveTrove:Clean()
	self._ReservedBy:Set(nil)

	-- UPDATE: Set the LockedPlayer to the grabbing player immediately
	-- This ensures clients update their prompts/UI as soon as the grab occurs
	self._LockedPlayer:Set(player)

	-- 2. Clean previous hold data
	self._HoldTrove:Clean()

	rootPart.Anchored = false

	-- 4. Assign Network Ownership
	-- This MUST happen before the client attempts to weld locally
	if rootPart:CanSetNetworkOwnership() then
		rootPart:SetNetworkOwner(player)
	end

	-- 5. Handle Character Death/Removing
	self._HoldTrove:Connect(player.CharacterRemoving, function()
		self:Drop(player)
	end)

	-- 6. Handle Player Leaving Game
	self._HoldTrove:Connect(player.AncestryChanged, function()
		if not player:IsDescendantOf(game) then
			self:Drop(player)
		end
	end)

	return true
end
function TreasureServer:Drop(player)
	-- 1. Clear the HoldTrove and State
	self._HoldTrove:Clean()
	self._HoldingPlayer:Set(nil)
	self._AttachedPlayerName:Set(nil)

	local rootPart = self.Instance.PrimaryPart
	if not rootPart then
		return
	end

	-- 3. Handle Reservation and Network Ownership Logic
	if player then
		-- Reserve the item for this player
		self._ReservedBy:Set(player)
		self._LockedPlayer:Set(player) -- Replicates to client to hide prompt

		-- FIX 1: Only set network ownership if the player doesn't already own it.
		-- Redundantly setting it causes a physics resync (stutter/lag).
		if rootPart:CanSetNetworkOwnership() and rootPart:GetNetworkOwner() ~= player then
			rootPart:SetNetworkOwner(player)
		end

		-- Start the monitoring logic in a spawned task
		self._ReserveTrove:Add(task.spawn(function()
			-- FIX 2: Wait a brief moment to allow the client's new falling velocity to replicate to the server.
			-- Without this, the server sees the velocity as 0 immediately and skips the while loop.
			task.wait(0.5)

			-- A. Wait for the treasure to stop moving
			while rootPart.AssemblyLinearVelocity.Magnitude > VELOCITY_THRESHOLD do
				task.wait(0.2)
				-- Safety check in case object is destroyed
				if not rootPart or not rootPart:IsDescendantOf(game) then
					return
				end
			end

			-- B. Wait the Lock Duration AFTER it has stopped
			task.wait(TreasureUtils.LOOT_LOCK_TIME)

			-- Safety check again
			if not rootPart or not rootPart:IsDescendantOf(game) then
				return
			end

			-- C. Unlock
			self._ReservedBy:Set(nil)
			self._LockedPlayer:Set(nil)

			-- Reset network owner to server and anchor
			if rootPart:CanSetNetworkOwnership() then
				rootPart:SetNetworkOwner(nil)
				rootPart.Anchored = true
			end
		end))
	else
		-- Force server drop (no player involved)
		if rootPart:CanSetNetworkOwnership() then
			rootPart:SetNetworkOwner(nil)
			rootPart.Anchored = true
		end
	end
end

function TreasureServer:ClaimFor(player) end

return TreasureServer
