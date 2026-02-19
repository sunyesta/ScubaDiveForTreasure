local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)
local Trove = require(ReplicatedStorage.Packages.Trove)
local MathUtils = require(ReplicatedStorage.NonWallyPackages.MathUtils)
local LootTable = require(ReplicatedStorage.Common.GameInfo.LootTable)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local TreasureUtils = {}

-- Interaction Constants
TreasureUtils.LOOT_LOCK_TIME = 10
-- Buoyancy Constants
TreasureUtils.BUOYANCY_ATTACH_NAME = "BuoyancyAttachment"
TreasureUtils.BUOYANCY_FORCE_NAME = "BuoyancyForce"
TreasureUtils.BOUY_ALIGN_POS_NAME = "BuoyancyAlignPosition"
TreasureUtils.BOUY_ALIGN_ROT_NAME = "BuoyancyAlignOrientation"

-- Physics Constants (Underwater Feel)
TreasureUtils.PHYSICS = {
	ROPE_LENGTH = 10,
	WATER_DRAG = 2.5, -- Higher = "Thicker" water (slows down faster)
	BUOYANCY_PCT = 0.8, -- 1.0 = Floating neutral, 0.8 = Slow sinking, >1.0 = Floating up
	GRAVITY = workspace.Gravity,
}

-- Instance Names
TreasureUtils.ALIGN_POS_NAME = "CarryAlignPosition"
TreasureUtils.ALIGN_ROT_NAME = "CarryAlignOrientation"
TreasureUtils.ATTACH_NAME = "CarryAttachment"
TreasureUtils.NO_COLLIDE_NAME = "CarryNoCollision"
TreasureUtils.PROXY_NAME = "CarryProxyPart"

-- Helper to find where to attach the treasure on the character
function TreasureUtils.GetAttachPoint(character)
	if not character then
		return nil, nil
	end

	local attachment = character:FindFirstChild("ChestCarryAttachment", true)
	if attachment then
		return attachment.Parent, attachment.WorldCFrame
	end

	local head = character:FindFirstChild("Head")
	if head then
		return head, head.CFrame * CFrame.new(0, 2, 0)
	end

	return nil, nil
end

--[[ 
    StartUnderwaterSimulation
    Runs a custom Heartbeat loop to simulate 2D underwater physics.
    Mathematically handles gravity, drag, and rope constraints on the Anchored proxy.
]]
function TreasureUtils.StartUnderwaterSimulation(proxyPart, character, charAttachment)
	local currentVelocity = Vector3.zero

	-- We assume the plane details are available in World2DUtils
	local planeOrigin = World2DUtils.DefaultPlaneOrigin or Vector3.zero
	local planeNormal = World2DUtils.DefaultPlaneNormal or Vector3.new(0, 0, 1)

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		-- 1. Cleanup checks
		if
			not proxyPart
			or not proxyPart.Parent
			or not character
			or not charAttachment
			or not charAttachment.Parent
		then
			if connection then
				connection:Disconnect()
			end
			return
		end

		-- Limit dt to prevent explosion on lag spikes
		dt = math.min(dt, 0.1)

		-- 2. Calculate Forces

		-- Gravity vs Buoyancy (Net Downward Force)
		-- If Buoyancy is 0.8, we apply 20% of gravity downwards.
		local netGravityAccel =
			Vector3.new(0, -TreasureUtils.PHYSICS.GRAVITY * (1 - TreasureUtils.PHYSICS.BUOYANCY_PCT), 0)

		-- Drag (Water Resistance)
		-- Force opposite to velocity: F = -k * v
		local dragAccel = -currentVelocity * TreasureUtils.PHYSICS.WATER_DRAG

		-- 3. Integrate Velocity (Euler)
		currentVelocity += (netGravityAccel + dragAccel) * dt

		-- 4. Tentative Position
		local currentPos = proxyPart.Position
		local newPos = currentPos + (currentVelocity * dt)

		-- 5. Apply Constraints

		-- Constraint A: 2D Plane Projection
		-- Project newPos onto the plane defined by Normal and Origin
		local toPoint = newPos - planeOrigin
		local distToPlane = toPoint:Dot(planeNormal)
		newPos = newPos - (planeNormal * distToPlane)

		-- Constraint B: Rope Tether (Distance Constraint)
		local anchorPos = charAttachment.WorldPosition

		-- Also project anchorPos to plane to ensure the rope calculation happens in 2D space
		local anchorToPoint = anchorPos - planeOrigin
		local anchorDistToPlane = anchorToPoint:Dot(planeNormal)
		local planarAnchorPos = anchorPos - (planeNormal * anchorDistToPlane)

		local vectorToProxy = newPos - planarAnchorPos
		local distance = vectorToProxy.Magnitude
		local maxLength = TreasureUtils.PHYSICS.ROPE_LENGTH

		if distance > maxLength then
			local direction = vectorToProxy.Unit

			-- Snap position to radius
			newPos = planarAnchorPos + (direction * maxLength)

			-- Correct Velocity: Remove component of velocity pointing OUT of the circle
			-- This simulates the "tug" of the rope halting outward movement
			local outwardSpeed = currentVelocity:Dot(direction)
			if outwardSpeed > 0 then
				currentVelocity = currentVelocity - (direction * outwardSpeed)
			end
		end

		-- 6. Apply to Proxy
		proxyPart.CFrame = CFrame.new(newPos)
	end)

	return connection
end

-- Creates the Anchored Proxy Part and starts the custom physics loop
function TreasureUtils.CreateProxyRig(character, prototypePart)
	if not character then
		return nil, nil
	end

	local attachPart, attachCFrame = TreasureUtils.GetAttachPoint(character)
	if not attachPart then
		return nil, nil
	end

	-- 1. Create the Proxy Part
	-- NOTE: It is Anchored. We move it manually in the loop.
	local proxy = Instance.new("Part")
	proxy.Name = TreasureUtils.PROXY_NAME
	proxy.Size = Vector3.new(1, 1, 1)
	proxy.Transparency = 1
	proxy.CanCollide = false
	proxy.Anchored = true
	proxy.Parent = workspace

	-- Start position: At the prototype's location, or strictly below player if nil
	if prototypePart then
		proxy.Position = prototypePart.Position
	else
		proxy.Position = attachCFrame.Position - Vector3.new(0, 5, 0)
	end

	-- 2. Create Attachment on Character (The Anchor Point)
	local charAtt = Instance.new("Attachment")
	charAtt.Name = TreasureUtils.ATTACH_NAME
	charAtt.CFrame = attachPart.CFrame:Inverse() * attachCFrame
	charAtt.Parent = attachPart

	-- 3. Create Attachment on Proxy (Target for the Chest)
	local proxyAtt = Instance.new("Attachment")
	proxyAtt.Name = TreasureUtils.ATTACH_NAME
	proxyAtt.Parent = proxy

	-- 4. Start the Physics Simulation
	TreasureUtils.StartUnderwaterSimulation(proxy, character, charAtt)

	return proxy, charAtt
end

-- Attaches the Chest (Physical 3D Object) to the Proxy (Simulated 2D Object)
function TreasureUtils.Attach(rootPart, character, proxyPart)
	if not rootPart or not character or not proxyPart then
		return nil
	end

	-- 1. Setup Source Attachment (Chest)
	local sourceAtt = rootPart:FindFirstChild(TreasureUtils.ATTACH_NAME)
	if not sourceAtt then
		sourceAtt = Instance.new("Attachment")
		sourceAtt.Name = TreasureUtils.ATTACH_NAME
		sourceAtt.Parent = rootPart
	end

	-- 2. Setup Goal Attachment (Proxy)
	local goalAtt = proxyPart:FindFirstChild(TreasureUtils.ATTACH_NAME)
	if not goalAtt then
		goalAtt = Instance.new("Attachment")
		goalAtt.Name = TreasureUtils.ATTACH_NAME
		goalAtt.Parent = proxyPart
	end

	-- 3. AlignPosition
	-- The Chest physically chases the Proxy
	local alignPos = Instance.new("AlignPosition")
	alignPos.Name = TreasureUtils.ALIGN_POS_NAME
	alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
	alignPos.Attachment0 = sourceAtt
	alignPos.Attachment1 = goalAtt
	alignPos.Responsiveness = 50 -- Lower responsiveness = "heavy" feel
	alignPos.MaxForce = math.huge
	alignPos.Parent = rootPart

	-- 4. AlignOrientation
	-- Keeps chest upright or matching proxy rotation
	local alignRot = Instance.new("AlignOrientation")
	alignRot.Name = TreasureUtils.ALIGN_ROT_NAME
	alignRot.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	alignRot.Attachment0 = sourceAtt
	alignRot.Attachment1 = goalAtt
	alignRot.Responsiveness = 50
	alignRot.MaxTorque = math.huge
	alignRot.Parent = rootPart

	-- 5. No Collision (Chest <-> Character)
	for _, charPart in pairs(character:GetChildren()) do
		if charPart:IsA("BasePart") then
			local noCollide = Instance.new("NoCollisionConstraint")
			noCollide.Name = TreasureUtils.NO_COLLIDE_NAME
			noCollide.Part0 = rootPart
			noCollide.Part1 = charPart
			noCollide.Parent = rootPart
		end
	end

	-- 6. Cleanup Physics Properties on Chest
	rootPart.Anchored = false
	rootPart.Massless = false
	-- We don't need buoyancy on the chest itself anymore,
	-- because AlignPosition will hold it up against gravity.

	return alignPos
end

-- Detach cleans up the chest constraints
function TreasureUtils.Detach(rootPart)
	if not rootPart then
		return
	end

	for _, child in pairs(rootPart:GetChildren()) do
		if
			child.Name == TreasureUtils.ALIGN_POS_NAME
			or child.Name == TreasureUtils.ALIGN_ROT_NAME
			or child.Name == TreasureUtils.NO_COLLIDE_NAME
		then
			child:Destroy()
		end

		if child.Name == TreasureUtils.ATTACH_NAME and child:IsA("Attachment") then
			child:Destroy()
		end
	end

	rootPart.Anchored = false
end

-- Applies an upward force to counteract gravity
-- strength: 0 to 1 (0.9 = 90% gravity cancellation)
-- duration: (Optional) How long the force lasts in seconds.
function TreasureUtils.ApplyBuoyancy(part: BasePart, strength: number, duration: number?)
	local trove = Trove.new()

	-- 1. Create Proxy (The Ghost that floats)
	-- We clone the part so it has the same size/shape for basic physics approximation
	-- IMPORTANT: Must be UNANCHORED for VectorForce to move it.
	local proxy = trove:Add(part:Clone())
	proxy.Name = "BuoyancyProxy"
	proxy.Transparency = 1
	proxy.CanCollide = true
	proxy.Anchored = false
	proxy.Massless = false -- Must have mass for forces to work
	proxy:ClearAllChildren() -- Remove existing scripts/constraints from the clone
	proxy.CFrame = part.CFrame -- Start exactly where the chest is
	proxy.Parent = workspace

	World2DUtils.ConstrainToPlane(proxy)

	-- 2. Create Attachments
	-- One on the Proxy (to pull it up)
	local proxyAtt = trove:Add(Instance.new("Attachment"))
	proxyAtt.Name = "ProxyAttachment"
	proxyAtt.Parent = proxy

	-- One on the Real Part (to be pulled towards the proxy)
	local partAtt = trove:Add(Instance.new("Attachment"))
	partAtt.Name = TreasureUtils.BUOYANCY_ATTACH_NAME
	partAtt.Parent = part

	-- 3. Apply Buoyancy Force to Proxy
	-- Force = Mass * Gravity * Strength (Upwards)
	local force = trove:Add(Instance.new("VectorForce"))
	force.Name = TreasureUtils.BUOYANCY_FORCE_NAME
	force.Attachment0 = proxyAtt
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true

	-- Calculate force required to float this specific proxy
	local totalMass = proxy.AssemblyMass
	if totalMass == 0 then
		totalMass = proxy:GetMass()
	end

	force.Force = Vector3.new(0, totalMass * workspace.Gravity * strength, 0)
	force.Parent = proxy

	-- 4. Align Chest to Proxy
	-- The Chest uses physics to chase the Proxy
	local alignPos = trove:Add(Instance.new("AlignPosition"))
	alignPos.Name = TreasureUtils.BOUY_ALIGN_POS_NAME -- Reusing name so Detach() can clean it later if needed
	alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
	alignPos.Attachment0 = partAtt -- Forces applied to Part...
	alignPos.Attachment1 = proxyAtt -- ...to move it to Proxy
	alignPos.Responsiveness = 25 -- Lower responsiveness = smoother, "heavier" underwater feel
	alignPos.MaxForce = math.huge
	alignPos.Parent = part

	-- 5. Align Orientation (ADDED)
	-- Keeps the chest rotation matched with the proxy
	local alignRot = trove:Add(Instance.new("AlignOrientation"))
	alignRot.Name = TreasureUtils.BOUY_ALIGN_ROT_NAME
	alignRot.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	alignRot.Attachment0 = partAtt
	alignRot.Attachment1 = proxyAtt
	alignRot.Responsiveness = 25
	alignRot.MaxTorque = math.huge
	alignRot.Parent = part

	-- 6. No Collision between Chest and Proxy
	-- Prevents physics jitters if they overlap
	local noCollide = trove:Add(Instance.new("NoCollisionConstraint"))
	noCollide.Name = TreasureUtils.NO_COLLIDE_NAME
	noCollide.Part0 = part
	noCollide.Part1 = proxy
	noCollide.Parent = proxy

	-- 7. Handle Duration
	if duration then
		task.delay(duration, function()
			trove:Destroy()
		end)
	end

	return trove
end

function TreasureUtils.GetLoot(self)
	local seed = self.Instance:GetAttribute("RandomSeed")

	local possibleLoots = TableUtil.Keys(LootTable)

	local lootList = {}

	for _ = 1, 5 do
		table.insert(lootList, MathUtils.GetRandomFromList(possibleLoots, seed))
		seed += 1
	end

	return lootList
end

return TreasureUtils
