--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Input = require(ReplicatedStorage.Packages.Input)
local CreateProximityPrompt = require(ReplicatedStorage.Common.Modules.GameUtils.CreateProximityPrompt)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local TreasureUtils = require(ReplicatedStorage.Common.Modules.ComponentUtils.TreasureUtils)
local LootDisplayGui = require(ReplicatedStorage.Common.Components.GUIs.LootDisplayGui)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable

local Player = Players.LocalPlayer
local Keyboard = Input.Keyboard.new()

local DropSound = GetAssetByName("BubbleAlert")

local hitSounds = {
	GetAssetByName("Hit1"),
	GetAssetByName("Hit2"),
	GetAssetByName("Hit3"),
	GetAssetByName("Hit4"),
}

local TreasureClient = Component.new({
	Tag = "Treasure",
	Ancestors = { Workspace },
})

function TreasureClient:Construct()
	self._Trove = Trove.new()
	self._Comm = ClientComm.new(self.Instance, true, "_Comm")
	self._CommObject = self._Comm:BuildObject()

	self._LockedPlayer = self._Comm:GetProperty("LockedPlayer")

	self._GrabProximityPrompt = CreateProximityPrompt(self.Instance, "Grab")
	self._AttachedPlayerName = Property.BindToAttribute(self.Instance, "_AttachedPlayerName", nil)

	self._InputTrove = self._Trove:Extend()
	self._GrabTrove = self._Trove:Extend()

	-- New: Specific trove for buoyancy to prevent conflicts with GrabTrove
	self._BuoyancyTrove = self._Trove:Extend()

	self._lastDropTime = 0
	self._lastHitTime = 0
	self._Claimed = false
end

function TreasureClient:Start()
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))

	partStreamable:Observe(function(rootPart, loadedTrove)
		if rootPart then
			self:Loaded(rootPart, loadedTrove)
		end
	end)
end

function TreasureClient:Loaded(rootPart, trove)
	self._HitSounds = {}

	for _, hitSound in hitSounds do
		local newHitSound = trove:Add(hitSound:Clone())
		newHitSound.Parent = rootPart
		table.insert(self._HitSounds, newHitSound)
	end

	trove:Add(self._GrabProximityPrompt.Triggered:Connect(function()
		self:_Grab()
	end))

	trove:Add(self._AttachedPlayerName:Observe(function()
		self:_UpdateState()
	end))

	trove:Add(self._LockedPlayer:Observe(function()
		self:_UpdateState()
	end))

	self:_SetupBounceSounds(rootPart, trove)
end

function TreasureClient:Stop()
	self._Trove:Clean()
end

function TreasureClient:_UpdateState()
	local holderName = self._AttachedPlayerName:Get()
	local lockedPlayer = self._LockedPlayer:Get()

	local amIHolding = (holderName == Player.Name)
	local isHeldByAnyone = (holderName ~= nil)

	local isLockedByMe = (lockedPlayer == Player)
	local isLockedByOther = (lockedPlayer ~= nil and lockedPlayer ~= Player)

	local timeSinceDrop = os.clock() - self._lastDropTime
	local onCooldown = timeSinceDrop < 2

	-- Update Prompt Visibility
	if isHeldByAnyone or isLockedByOther or onCooldown then
		self._GrabProximityPrompt.Enabled = false
	else
		self._GrabProximityPrompt.Enabled = true
	end

	-- Input Handling
	self._InputTrove:Clean()

	if amIHolding then
		self._InputTrove:Add(Keyboard.KeyUp:Connect(function(key)
			if key == Enum.KeyCode.Backspace then
				self:_Release()
			end
		end))
	else
		-- If we aren't holding it, ensure physics are detached
		if self.Instance.PrimaryPart then
			TreasureUtils.Detach(self.Instance.PrimaryPart)
		end

		-- Only clean the GrabTrove (ropes/proxies) if we truly lost ownership/lock
		-- This prevents fighting with _Release
		if not isLockedByMe then
			self._GrabTrove:Clean()
			self._BuoyancyTrove:Clean() -- Clean buoyancy only when we lose the lock
		end
	end
end

function TreasureClient:_Grab()
	if os.clock() - self._lastDropTime < 2 then
		return
	end

	self._GrabProximityPrompt.Enabled = false

	-- Clean up any active buoyancy sinking immediately
	self._BuoyancyTrove:Clean()
	self._GrabTrove:Clean()

	local primaryPart = self.Instance.PrimaryPart
	if not primaryPart then
		return
	end

	primaryPart.AssemblyLinearVelocity = Vector3.zero
	primaryPart.AssemblyAngularVelocity = Vector3.zero

	-- 1. Create the Client-Side Proxy Rig
	local proxyPart, charAtt = TreasureUtils.CreateProxyRig(Player.Character, primaryPart)

	if proxyPart then
		self._GrabTrove:Add(proxyPart)
	end
	if charAtt then
		self._GrabTrove:Add(charAtt)
	end

	-- 2. Pre-Response: Force CFrame locally for instant feedback
	local preGrabTrove = self._GrabTrove:Extend()
	if proxyPart then
		preGrabTrove:Add(RunService.RenderStepped:Connect(function()
			if self.Instance.PrimaryPart then
				self.Instance.PrimaryPart.CFrame = proxyPart.CFrame
			end
		end))
	end

	-- 3. Request Grab from Server
	self._CommObject:Grab():andThen(function(success)
		-- Stop forcing CFrame, let Physics take over
		preGrabTrove:Clean()

		if not success then
			self:_UpdateState()
			return
		end

		-- 4. Server gave ownership. Apply Constraints.
		if self.Instance.PrimaryPart and proxyPart then
			TreasureUtils.Attach(self.Instance.PrimaryPart, Player.Character, proxyPart)
			self:_SetupCollisionDrop()
		end
	end)
end

function TreasureClient:_SetupBounceSounds(rootPart, trove)
	trove:Add(rootPart.Touched:Connect(function(hit)
		if self._AttachedPlayerName:Get() ~= nil then
			return
		end
		if hit:IsDescendantOf(Player.Character) then
			return
		end

		if os.clock() - self._lastHitTime < 0.15 then
			return
		end
		if rootPart.AssemblyLinearVelocity.Magnitude < 3 then
			return
		end

		self._lastHitTime = os.clock()

		if #self._HitSounds > 0 then
			local randomIndex = math.random(1, #self._HitSounds)
			local randomSound = self._HitSounds[randomIndex]
			randomSound.PlaybackSpeed = math.random(90, 110) / 100
			randomSound:Play()
		end
	end))
end

function TreasureClient:_SetupCollisionDrop()
	local primaryPart = self.Instance.PrimaryPart
	if not primaryPart then
		return
	end

	-- Add the connection to GrabTrove so it disconnects automatically when we drop it
	self._GrabTrove:Add(primaryPart.Touched:Connect(function(hit)
		if CollectionService:HasTag(hit, "TreasureDeposit") then
			self:Claim()
			return
		end

		local isFish = false
		if hit.Parent and CollectionService:HasTag(hit.Parent, "Fish") then
			isFish = true
		end

		if not hit.CanCollide and not isFish then
			return
		end

		if hit:IsDescendantOf(self.Instance) then
			return
		end

		if hit:IsDescendantOf(Player.Character) then
			return
		end

		if hit.Name == "CarryProxyPart" then
			return
		end

		if hit.Name == "BuoyancyProxy" then
			return
		end

		print("Treasure collided with:", hit.Name, "Dropping!")
		self:_Release()
	end))
end

function TreasureClient:_Release()
	self._InputTrove:Clean()
	self._GrabTrove:Clean() -- Cleans constraints, ropes, and the Touched event
	self._BuoyancyTrove:Clean() -- Clean any old buoyancy before starting new

	DropSound:Play()

	local part = self.Instance.PrimaryPart

	if part then
		TreasureUtils.Detach(part)

		-- Slow it down
		local currentVel = part.AssemblyLinearVelocity
		part.AssemblyLinearVelocity = Vector3.new(currentVel.X * 0.2, math.min(currentVel.Y, 0), currentVel.Z * 0.2)
		part.AssemblyAngularVelocity = part.AssemblyAngularVelocity * 0.1

		-- FIX 2: Buoyancy Logic
		-- Removed duration (previously 2) so it persists until Grab or Lock Loss
		local buoyancy = TreasureUtils.ApplyBuoyancy(part, 0.9)
		self._BuoyancyTrove:Add(buoyancy)
	end

	self._lastDropTime = os.clock()
	self:_UpdateState() -- Prompt is now disabled (Cooldown)

	-- FIX 3: Re-enable Prompt
	-- Wait 2 seconds, then update state again to re-enable prompt
	self._Trove:Add(task.delay(2.1, function()
		self:_UpdateState()
	end))

	self._CommObject:Drop()
end

function TreasureClient:Claim()
	if not self._Claimed then
		self._Claimed = true
		self.Instance:Destroy()
		self._CommObject:Claim()

		LootDisplayGui.DisplayLoot({
			"Necklace",
			"Rock",
			"Yoyo",
			"Plate",
			"Necklace",
			"Rock",
		})
	end
end

return TreasureClient
