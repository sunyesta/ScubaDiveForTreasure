local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)

local LOCK_TIME = 10

local TreasureServer = Component.new({
	Tag = "Treasure",
	Ancestors = { Workspace },
})

function TreasureServer:Construct()
	assert(self.Instance.PrimaryPart, "No Primary part found for Treasure")

	self._Trove = Trove.new()
	self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm"))

	-- Synced attribute for clients to know state
	self._LockedPlayerIsAttached = Property.BindToAttribute(self.Instance, "LockedPlayerIsAttached", false)
	-- UPDATED: Renamed to LockedPlayerName
	self._LockedPlayerName = Property.BindToAttribute(self.Instance, "LockedPlayerName", nil)

	-- Variable to track the countdown thread
	self._UnlockThread = nil
end

function TreasureServer:Start()
	-- Bind Grab Function
	self._Comm:BindFunction("Grab", function(player)
		-- Check if the player is allowed to grab
		local currentLockName = self._LockedPlayerName:Get()
		local isAttached = self._LockedPlayerIsAttached:Get()

		-- Fail if: (Locked to someone else) OR (Already attached/held)
		-- UPDATED: Comparison uses name strings now
		if (currentLockName ~= nil and currentLockName ~= player.Name) or isAttached then
			return false
		end

		self:Grab(player)
		return true
	end)

	-- Bind Drop Function
	self._Comm:BindFunction("Drop", function(player)
		-- Allowed if: Is Attached AND The player requesting drop is the Locked Player
		-- UPDATED: Comparison uses name strings now
		if self._LockedPlayerIsAttached:Get() and self._LockedPlayerName:Get() == player.Name then
			self:Drop(player)
			return true
		end
		return false
	end)
end

function TreasureServer:Stop()
	-- Clean up the timer if the object is destroyed
	if self._UnlockThread then
		task.cancel(self._UnlockThread)
		self._UnlockThread = nil
	end
	self._Trove:Clean()
end

function TreasureServer:Grab(player)
	-- If there is a pending unlock timer (e.g., they dropped it and picked it back up quickly), cancel it.
	if self._UnlockThread then
		task.cancel(self._UnlockThread)
		self._UnlockThread = nil
	end

	-- Set the locked player to the person grabbing it
	-- UPDATED: Storing Name string
	self._LockedPlayerName:Set(player.Name)
	self._LockedPlayerIsAttached:Set(true)
end

function TreasureServer:Drop(player)
	self._LockedPlayerIsAttached:Set(false)

	-- Start the countdown to unlock the item
	self._UnlockThread = task.delay(LOCK_TIME, function()
		self._LockedPlayerName:Set(nil)
		self._UnlockThread = nil
	end)
end

return TreasureServer
