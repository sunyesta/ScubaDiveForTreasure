local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Input = require(ReplicatedStorage.Packages.Input)
local CreateProximityPrompt = require(ReplicatedStorage.Common.Modules.GameUtils.CreateProximityPrompt)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local LocalizeModel = require(ReplicatedStorage.Common.Modules.GameUtils.LocalizeModel)

local Player = Players.LocalPlayer
local Keyboard = Input.Keyboard.new()

local TreasureClient = Component.new({
	Tag = "Treasure",
	Ancestors = { Workspace },
})

TreasureClient._WELD_NAME = "HoldWeld"
TreasureClient._LOOT_LOCK_TIME = 2

function TreasureClient:Construct()
	LocalizeModel(self.Instance)

	self._Trove = Trove.new()
	self._Comm = ClientComm.new(self.Instance, true, "_Comm"):BuildObject()

	self._GrabProximityPrompt = CreateProximityPrompt(self.Instance, "Grab")

	self._LockedPlayerIsAttached = Property.BindToAttribute(self.Instance, "LockedPlayerIsAttached", false)
	self._LockedPlayerName = Property.BindToAttribute(self.Instance, "LockedPlayerName", nil)
end

function TreasureClient:Start()
	-- 1. Update Interaction/Visuals
	local function updateState()
		local lockedPlayerName = self._LockedPlayerName:Get()
		local isAttached = self._LockedPlayerIsAttached:Get()

		-- Proximity Prompt Logic
		if (lockedPlayerName == Player.Name or lockedPlayerName == nil) and not isAttached then
			self._GrabProximityPrompt:SetAttribute("ProxEnabled", true)
		else
			self._GrabProximityPrompt:SetAttribute("ProxEnabled", false)
		end

		-- Transparency Logic
		if lockedPlayerName == Player.Name or lockedPlayerName == nil or isAttached then
			self.Instance.Hitbox.Transparency = 0
		else
			self.Instance.Hitbox.Transparency = 0.5
		end
	end

	self._Trove:Add(self._LockedPlayerName:Observe(updateState))
	self._Trove:Add(self._LockedPlayerIsAttached:Observe(updateState))

	-- 2. Listen for Prompt Trigger
	self._Trove:Add(self._GrabProximityPrompt.Triggered:Connect(function()
		self:_Grab()
	end))

	-- 3. Handle Physical Attachment
	local attachedTrove = self._Trove:Extend()

	local function updateAttachment()
		local isAttached = self._LockedPlayerIsAttached:Get()
		local lockedPlayerName = self._LockedPlayerName:Get()

		-- We clean previous attachments/events whenever state changes to avoid duplication
		attachedTrove:Clean()

		if isAttached and lockedPlayerName then
			local lockedPlayer = Players:FindFirstChild(lockedPlayerName)

			-- Only attach if the player exists in Workspace
			if lockedPlayer and lockedPlayer.Character then
				self:_AttachTo(lockedPlayer)

				-- If I am the one holding it, listen for Drop input
				if lockedPlayer == Player then
					attachedTrove:Add(Keyboard.KeyUp:Connect(function(keycode)
						if keycode == Enum.KeyCode.L then
							self:_Drop()
						end
					end))
				end
			end
		else
			self:_ReleaseAttached()
		end
	end

	-- Observe both, as we need the Player Name AND the Boolean to attach correctly
	self._Trove:Add(self._LockedPlayerIsAttached:Observe(updateAttachment))
	self._Trove:Add(self._LockedPlayerName:Observe(updateAttachment))
end

function TreasureClient:Stop()
	self._Trove:Clean()
end

function TreasureClient:_Grab()
	self._LockedPlayerIsAttached:Set(true)
	self._LockedPlayerName:Set(Player.Name)
	self._Comm:Grab()
end

function TreasureClient:_Drop()
	self._LockedPlayerIsAttached:Set(false)
	self._Comm:Drop()
end

function TreasureClient:_GetAttachPoint(character)
	if not character then
		return nil, nil
	end

	local attachment = character:FindFirstChild("OverheadCarryAttachment", true)
	if attachment then
		return attachment.Parent, attachment.WorldCFrame
	end

	local head = character:FindFirstChild("Head")
	if head then
		return head, head.CFrame * CFrame.new(0, 2, 0)
	end

	return nil, nil
end

function TreasureClient:_AttachTo(player)
	local character = player.Character
	local rootPart = self.Instance.PrimaryPart
	if not rootPart or not character then
		return nil
	end

	local attachPart, attachCFrame = self:_GetAttachPoint(character)
	if not attachPart then
		return nil
	end

	-- 1. Position the part (Visual feedback)
	rootPart.CFrame = attachCFrame

	-- 2. Clean existing welds
	for _, child in pairs(rootPart:GetChildren()) do
		if child.Name == TreasureClient._WELD_NAME and child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end

	-- 3. Create Weld
	local weld = Instance.new("WeldConstraint")
	weld.Name = TreasureClient._WELD_NAME
	weld.Part0 = attachPart
	weld.Part1 = rootPart
	weld.Parent = rootPart
	weld.Enabled = true

	-- 4. Physics Properties
	rootPart.Massless = true
	rootPart.CanCollide = false
	rootPart.Anchored = false -- This unanchors it so it can move with the player

	if self.Instance:FindFirstChild("Hitbox") then
		self.Instance.Hitbox.CanCollide = false
	end

	return weld
end

function TreasureClient:_ReleaseAttached()
	local rootPart = self.Instance.PrimaryPart
	if not rootPart then
		return
	end

	-- 1. Disable/Destroy Weld(s)
	for _, child in pairs(rootPart:GetChildren()) do
		if child.Name == TreasureClient._WELD_NAME and child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end

	-- 2. Restore Physics Properties
	rootPart.Massless = false
	rootPart.CanCollide = true

	-- FIXED: Removed "rootPart.Anchored = false"
	-- This prevents the treasure from unanchoring immediately on spawn.
	-- It will only be unanchored after it has been picked up (via _AttachTo) and dropped.
	-- rootPart.Anchored = false

	local hitbox = self.Instance:FindFirstChild("Hitbox")
	if hitbox then
		hitbox.CanCollide = true
	end
end

return TreasureClient
