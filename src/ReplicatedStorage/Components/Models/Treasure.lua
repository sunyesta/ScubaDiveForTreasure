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
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local SpawnVisualEffect = require(ReplicatedStorage.Common.Modules.GameUtils.SpawnVisualEffect)
local LootRevealGui = require(ReplicatedStorage.Common.Components.GUIs.LootRevealGui)

local Player = Players.LocalPlayer
local Keyboard = Input.Keyboard.new()

local DropSound = GetAssetByName("BubbleAlert")
local BreakSound = GetAssetByName("BreakSound")

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

TreasureClient.HoldingTreasure = Property.new(nil)

function TreasureClient:Construct()
	self._Trove = Trove.new()
	self._Comm = ClientComm.new(self.Instance, true, "_Comm")
	self._CommObject = self._Comm:BuildObject()

	self._LockedPlayer = self._Comm:GetProperty("LockedPlayer")

	self._GrabProximityPrompt = CreateProximityPrompt(self.Instance, "Grab")
	self._AttachedPlayerName = Property.BindToAttribute(self.Instance, "_AttachedPlayerName", nil)

	self._InputTrove = self._Trove:Extend()
	self._GrabTrove = self._Trove:Extend()
	self._BuoyancyTrove = self._Trove:Extend()

	self._lastDropTime = 0
	self._lastHitTime = 0
	self._lastGrabTime = 0
	self._Claimed = false

	self.GrabSound = GetAssetByName("ChestPickup")
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

	trove:Add(self._CommObject.Broken:Connect(function(player)
		if player ~= Player then
			self:Break()
		end
	end))

	self:_SetupBounceSounds(rootPart, trove)
end

function TreasureClient:Stop()
	self._Trove:Clean()
end

function TreasureClient:_UpdateState()
	if self._Claimed then
		self._GrabProximityPrompt.Enabled = false
		return
	end

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
				self:Release()
			end
		end))
	else
		if self.Instance.PrimaryPart then
			TreasureUtils.Detach(self.Instance.PrimaryPart)
		end

		if not isLockedByMe then
			self._GrabTrove:Clean()
			self._BuoyancyTrove:Clean()
		end
	end
end

function TreasureClient:_Grab()
	self.GrabSound:Play()

	if os.clock() - self._lastDropTime < 2 then
		return
	end

	self._GrabProximityPrompt.Enabled = false
	self._BuoyancyTrove:Clean()
	self._GrabTrove:Clean()

	local primaryPart = self.Instance.PrimaryPart
	if not primaryPart then
		return
	end

	TreasureClient.HoldingTreasure:Set(self)
	self._GrabTrove:Add(function()
		TreasureClient.HoldingTreasure:Set(nil)
	end)

	primaryPart.AssemblyLinearVelocity = Vector3.zero
	primaryPart.AssemblyAngularVelocity = Vector3.zero

	local proxyPart, charAtt = TreasureUtils.CreateProxyRig(Player.Character, primaryPart)

	if proxyPart then
		self._GrabTrove:Add(proxyPart)
	end
	if charAtt then
		self._GrabTrove:Add(charAtt)
	end

	local preGrabTrove = self._GrabTrove:Extend()
	if proxyPart then
		preGrabTrove:Add(RunService.RenderStepped:Connect(function()
			if self.Instance.PrimaryPart then
				self.Instance.PrimaryPart.CFrame = proxyPart.CFrame
			end
		end))
	end

	self._CommObject:Grab():andThen(function(success)
		preGrabTrove:Clean()

		if not success then
			self:_UpdateState()
			return
		end

		if self.Instance.PrimaryPart and proxyPart then
			self._lastGrabTime = os.clock()
			TreasureUtils.Attach(self.Instance.PrimaryPart, Player.Character, proxyPart)
			self:_SetupCollisionDrop()
		end
	end)
end

function TreasureClient:_SetupBounceSounds(rootPart, trove)
	trove:Add(rootPart.Touched:Connect(function(hit)
		if self._AttachedPlayerName:Get() ~= nil or self._Claimed then
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

	self._GrabTrove:Add(primaryPart.Touched:Connect(function(hit)
		if os.clock() - self._lastGrabTime < 1.0 then
			return
		end

		local isDropPart = false
		if InstanceUtils.FindFirstAncestorWithTag(hit, "DropPart") then
			isDropPart = true
		end

		if not isDropPart then
			return
		end

		if hit:IsDescendantOf(self.Instance) or hit:IsDescendantOf(Player.Character) then
			return
		end

		if hit.Name == "CarryProxyPart" or hit.Name == "BuoyancyProxy" then
			return
		end

		self:Release()
	end))
end

function TreasureClient:Release()
	if self._Claimed then
		return
	end

	self._InputTrove:Clean()
	self._GrabTrove:Clean()
	self._BuoyancyTrove:Clean()

	DropSound:Play()

	local part = self.Instance.PrimaryPart

	if part then
		TreasureUtils.Detach(part)

		local currentVel = part.AssemblyLinearVelocity
		part.AssemblyLinearVelocity = Vector3.new(currentVel.X * 0.2, math.min(currentVel.Y, 0), currentVel.Z * 0.2)
		part.AssemblyAngularVelocity = part.AssemblyAngularVelocity * 0.1

		local buoyancy = TreasureUtils.ApplyBuoyancy(part, 0.9)
		self._BuoyancyTrove:Add(buoyancy)
	end

	self._lastDropTime = os.clock()
	self:_UpdateState()

	self._Trove:Add(task.delay(2.1, function()
		self:_UpdateState()
	end))

	self._CommObject:Drop()
end

function TreasureClient:Claim(depositInstance)
	if self._Claimed then
		return
	end
	self._Claimed = true

	-- 1. Detach from player immediately
	self._InputTrove:Clean()
	self._GrabTrove:Clean()
	self._BuoyancyTrove:Clean()

	-- Ensure global hold state is cleared so player can act immediately
	if TreasureClient.HoldingTreasure:Get() == self then
		TreasureClient.HoldingTreasure:Set(nil)
	end

	-- 2. Setup Animation
	local primaryPart = self.Instance.PrimaryPart
	if primaryPart and depositInstance then
		TreasureUtils.Detach(primaryPart)
		primaryPart.Anchored = true
		primaryPart.CanCollide = false

		-- Play sound if you have a specific success sound, otherwise DropSound works
		if self.GrabSound then
			self.GrabSound:Play()
		end

		local startCFrame = self.Instance:GetPivot()
		local targetCFrame = depositInstance.CFrame
		local startScale = self.Instance:GetScale()

		local duration = 0.5
		local startTime = os.clock()

		-- 3. Animate Loop
		-- Using task.spawn so we don't yield the main thread logic
		task.spawn(function()
			while true do
				local elapsed = os.clock() - startTime
				local alpha = math.clamp(elapsed / duration, 0, 1)

				-- Easing: Quad In (Start slow, end fast - nice for "sucking" effect)
				local ease = alpha * alpha

				-- Interpolate Position
				local currentCF = startCFrame:Lerp(targetCFrame, ease)

				-- Add Spin (2 full rotations)
				currentCF = currentCF * CFrame.Angles(0, math.rad(360 * 2 * ease), 0)

				if self.Instance and self.Instance.PrimaryPart then
					self.Instance:PivotTo(currentCF)
					-- Shrink to 0.1 scale
					self.Instance:ScaleTo(startScale * (1 - (ease * 0.9)))
				else
					break
				end

				if alpha >= 1 then
					break
				end

				RunService.RenderStepped:Wait()
			end

			-- 4. Destroy after animation
			if self.Instance then
				self.Instance:Destroy()
			end

			-- 5. Network & UI (Moved here so it doesn't destroy the part server-side too early)
			self._CommObject:Claim()
			local loot = TreasureUtils.GetLoot(self)
			LootRevealGui.DisplayLoot(loot)
		end)
	else
		-- Fallback if parts missing
		self.Instance:Destroy()
		self._CommObject:Claim()
		local loot = TreasureUtils.GetLoot(self)
		LootRevealGui.DisplayLoot(loot)
	end
end

function TreasureClient:Break()
	BreakSound:Play()
	if self.Instance.PrimaryPart then
		SpawnVisualEffect.WoodChips(self.Instance.PrimaryPart.Position, Color3.new(0.403921, 0.243137, 0.121568))
	end
	self.Instance:Destroy()
	self._CommObject:Break()
end

return TreasureClient
