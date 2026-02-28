local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable).Streamable
local PlayerUtils = require(ReplicatedStorage.NonWallyPackages.PlayerUtils)
local MovementController = require(ReplicatedStorage.Common.Controllers.MovementController)

-- Assuming World2DUtils is in this path based on your Urchin script
local World2DUtils = require(ReplicatedStorage.Common.Modules.GameUtils.World2DUtils)
local SoundUtils = require(ReplicatedStorage.NonWallyPackages.SoundUtils)

local Player = Players.LocalPlayer

-- == CONFIGURATION ==
local SQUISH_AMOUNT = 3
local SQUISH_TIME = 0.1
local RESTORE_TIME = 0.6

local BOUNCE_SPEED = 50 -- Target velocity magnitude
local BOUNCE_DURATION = 0.25 -- Duration to apply the force
local BOUNCE_FRICTION_OVERRIDE = 3
local BOUNCE_COOLDOWN = 0.3

local SpongePart = Component.new({
	Tag = "SpongePart",
	Ancestors = { Workspace },
})

function SpongePart:Construct()
	self._Trove = Trove.new()
	self._lastBounce = 0 -- Added a debounce timestamp similar to Urchin

	self.BoingSound = SoundUtils.MakeSound("rbxassetid://131916027000817", self.Instance, 1)

	self.Instance.CanCollide = false
end

function SpongePart:Start()
	local part: BasePart = self.Instance

	self.OriginalSize = part.Size
	self.OriginalCFrame = part.CFrame
	self.IsSquishing = false

	local touchConnection = part.Touched:Connect(function(hit: BasePart)
		if self.IsSquishing then
			return
		end

		local character = Player.Character
		-- Check if it is the local player hitting the part
		if character and hit:IsDescendantOf(character) then
			-- 1. Apply Physics Immediately (Passing the hit part to calculate normal)
			self:ApplyBounceForceToPlayer(hit)

			-- 2. Play Visuals (Spawned so it doesn't block other logic)
			task.spawn(function()
				self:DoSquish(hit)
			end)
		elseif PlayerUtils.GetPlayerFromPart(hit) then
			-- Handle other players (Visuals only)
			self:DoSquish(hit)
		end
	end)

	self._Trove:Add(touchConnection)
end

function SpongePart:DoSquish(hitPart: BasePart)
	self.IsSquishing = true

	self.BoingSound:Play()

	local part: BasePart = self.Instance

	local localPos = part.CFrame:PointToObjectSpace(hitPart.Position)

	local scaledX = localPos.X / part.Size.X
	local scaledY = localPos.Y / part.Size.Y
	local scaledZ = localPos.Z / part.Size.Z

	local absX, absY, absZ = math.abs(scaledX), math.abs(scaledY), math.abs(scaledZ)

	local localNormal: Vector3
	if absX > absY and absX > absZ then
		localNormal = Vector3.new(math.sign(localPos.X), 0, 0)
	elseif absZ > absX and absZ > absY then
		localNormal = Vector3.new(0, 0, math.sign(localPos.Z))
	else
		localNormal = Vector3.new(0, math.sign(localPos.Y), 0)
	end

	local lostX = math.abs(localNormal.X) * SQUISH_AMOUNT
	local lostY = math.abs(localNormal.Y) * SQUISH_AMOUNT
	local lostZ = math.abs(localNormal.Z) * SQUISH_AMOUNT

	local targetSize = Vector3.new(
		math.max(0.1, self.OriginalSize.X - lostX),
		math.max(0.1, self.OriginalSize.Y - lostY),
		math.max(0.1, self.OriginalSize.Z - lostZ)
	)

	local offsetCFrame =
		CFrame.new(-localNormal.X * (lostX / 2), -localNormal.Y * (lostY / 2), -localNormal.Z * (lostZ / 2))

	local targetCFrame = self.OriginalCFrame * offsetCFrame

	local squishTweenInfo = TweenInfo.new(SQUISH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local restoreTweenInfo = TweenInfo.new(RESTORE_TIME, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

	local squishTween = TweenService:Create(part, squishTweenInfo, {
		Size = targetSize,
		CFrame = targetCFrame,
	})

	local restoreTween = TweenService:Create(part, restoreTweenInfo, {
		Size = self.OriginalSize,
		CFrame = self.OriginalCFrame,
	})

	self._Trove:Add(squishTween)
	self._Trove:Add(restoreTween)

	squishTween:Play()
	squishTween.Completed:Wait()

	restoreTween:Play()
	restoreTween.Completed:Wait()

	self._Trove:Remove(squishTween)
	self._Trove:Remove(restoreTween)
	squishTween:Destroy()
	restoreTween:Destroy()

	self.IsSquishing = false
end

function SpongePart:ApplyBounceForceToPlayer(hitPart: BasePart)
	-- Check Debounce to prevent physics spam
	local now = os.clock()
	if now - self._lastBounce < BOUNCE_COOLDOWN then
		return
	end
	self._lastBounce = now

	local part: BasePart = self.Instance

	-- 1. Calculate the local hit normal (Using the same logic as your DoSquish method)
	local localPos = part.CFrame:PointToObjectSpace(hitPart.Position)
	local scaledX = localPos.X / part.Size.X
	local scaledY = localPos.Y / part.Size.Y
	local scaledZ = localPos.Z / part.Size.Z

	local absX, absY, absZ = math.abs(scaledX), math.abs(scaledY), math.abs(scaledZ)

	-- Determine which face was hit in object space
	local localNormal: Vector3
	if absX > absY and absX > absZ then
		localNormal = Vector3.new(math.sign(localPos.X), 0, 0)
	elseif absZ > absX and absZ > absY then
		localNormal = Vector3.new(0, 0, math.sign(localPos.Z))
	else
		localNormal = Vector3.new(0, math.sign(localPos.Y), 0)
	end

	-- 2. Convert that local face normal to a World Space normal
	local worldNormal = part.CFrame:VectorToWorldSpace(localNormal)

	-- 3. Project onto your 2D plane (same logic as the Urchin)
	local planeNormal = World2DUtils.DefaultPlaneNormal or Vector3.new(0, 0, 1)

	-- Project the direction onto the 2D plane so we don't push them "out" of the lane
	local bounceDirectionVector = worldNormal - (worldNormal:Dot(planeNormal) * planeNormal)

	-- Fallback: If they somehow hit exactly perfectly on the plane normal (e.g. front/back of sponge)
	if bounceDirectionVector.Magnitude < 0.1 then
		bounceDirectionVector = Vector3.new(0, 1, 0) -- Default to an upward bounce
	end

	local bounceDirection = bounceDirectionVector.Unit

	-- 4. Calculate desired velocity and apply it
	local targetVelocity = bounceDirection * BOUNCE_SPEED
	MovementController.ApplyImpulse(targetVelocity)
end

function SpongePart:Stop()
	self._Trove:Clean()
end

return SpongePart
