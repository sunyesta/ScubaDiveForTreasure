local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)

-- Modules
local Treasure = require(ReplicatedStorage.Common.Components.Models.Treasure)
local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local UnderwaterPhysicsUtils = require(ReplicatedStorage.Common.Modules.UnderwaterPhysicsUtils)
local MovementController = require(ReplicatedStorage.Common.Controllers.MovementController)

-- Constants
local BOUNCE_SPEED = 100 -- Target velocity magnitude
local BOUNCE_DURATION = 0.25 -- Duration to apply the force
local BOUNCE_FRICTION_OVERRIDE = 5 -- Duration to apply the force
local BOUNCE_COOLDOWN = 0.5

local Player = Players.LocalPlayer

local Urchin = Component.new({
	Tag = "Urchin",
	Ancestors = { Workspace },
})

function Urchin:Construct()
	self._Trove = Trove.new()
	self._lastBounce = 0 -- Debounce timestamp
end

function Urchin:Start()
	-- Wait for the RootPart to stream in before setting up interactions
	local partStreamable = self._Trove:Add(Streamable.new(self.Instance, "RootPart"))

	self._Trove:Add(partStreamable:Observe(function(rootPart, loadedTrove)
		if rootPart then
			self:_Loaded(rootPart, loadedTrove)
		end
	end))
end

function Urchin:Stop()
	self._Trove:Clean()
end

function Urchin:_Loaded(rootPart, trove)
	trove:Add(rootPart.Touched:Connect(function(hit)
		-- 1. Handle Player Bounce
		local model = hit.Parent
		local player = Players:GetPlayerFromCharacter(model)

		-- Only run logic if *we* are the one touching it (Client-side prediction)
		if player == Player then
			self:_BouncePlayer(model, rootPart)
		end

		-- 2. Handle Treasure Breaking (Existing Logic)
		local treasureModel = InstanceUtils.FindFirstAncestorWithTag(hit, "Treasure")
		if treasureModel then
			local treasure = Treasure:FromInstance(treasureModel)
			if treasure then
				treasure:Break()
			end
		end
	end))
end

function Urchin:_BouncePlayer(character, urchinPart)
	-- Check Debounce
	local now = os.clock()
	if now - self._lastBounce < BOUNCE_COOLDOWN then
		return
	end
	self._lastBounce = now

	GetAssetByName("Spike"):Play()

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")

	if root and humanoid then
		local planeNormal = World2DUtils.DefaultPlaneNormal or Vector3.new(0, 0, 1)

		-- Calculate Direction strictly based on relative positions (Center-to-Center)
		local bounceDirectionVector = root.Position - urchinPart.Position

		-- Project the direction onto the 2D plane so we don't push them "out" of the lane
		-- Formula: V_plane = V - (V:Dot(N) * N)
		local diffPlane = bounceDirectionVector - (bounceDirectionVector:Dot(planeNormal) * planeNormal)

		-- Flatten the Y axis so we control verticality manually (jump height)
		-- We just want the horizontal "push away" direction relative to the plane
		local flatDiff = diffPlane * Vector3.new(1, 0, 1)

		if flatDiff.Magnitude < 0.1 then
			-- Fallback if they land exactly on top, push them right (relative to camera/plane)
			flatDiff = Vector3.new(1, 0, 0) - (Vector3.new(1, 0, 0):Dot(planeNormal) * planeNormal)
			if flatDiff.Magnitude < 0.1 then
				flatDiff = Vector3.new(0, 0, 1)
			end -- rare fallback
		end

		local flatDirection = flatDiff.Unit

		-- Calculate desired velocity vector
		-- Combined horizontal push with fixed vertical pop
		local targetVelocity = (flatDirection * BOUNCE_SPEED)

		-- Call our new utility module to handle the actual physics application!
		MovementController.ApplyExternalBounce(targetVelocity, BOUNCE_DURATION, BOUNCE_FRICTION_OVERRIDE)
	end
end

return Urchin
