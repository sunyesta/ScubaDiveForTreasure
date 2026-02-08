local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

local AnimatedHumanoid = {}
AnimatedHumanoid.__index = AnimatedHumanoid

-- // DEFAULT ANIMATION IDS (R15 Standard) //
-- These are used if a specific ID is not provided in the constructor.
local DEFAULTS = {
	Idle = "rbxassetid://507766388",
	Running = "rbxassetid://507767714",
	Jumping = "rbxassetid://507765000",
	Climbing = "rbxassetid://507765644",
	FreeFall = "rbxassetid://507767968",
	FallingDown = "rbxassetid://507767968", -- Often same as freefall
	Seated = "rbxassetid://2506281703",
	PlatformStanding = "rbxassetid://507766388", -- Reuse idle
	Dead = "rbxassetid://507766666",
	Swimming = "rbxassetid://913384386",
	GettingUp = "rbxassetid://507766388",
}

-- // CONSTRUCTOR //
function AnimatedHumanoid.new(humanoid, customAnimations)
	local self = setmetatable({}, AnimatedHumanoid)

	self._Trove = Trove.new()

	self.Humanoid = humanoid
	-- Ensure Animator exists for playing animations
	self.Animator = humanoid:WaitForChild("Animator", 5) or Instance.new("Animator", humanoid)

	self.Tracks = {}
	self.CurrentTrack = nil
	self.CurrentTrackName = ""

	-- Merge defaults with provided custom animations
	self.AnimationIds = {}
	customAnimations = customAnimations or {}

	for name, defaultId in pairs(DEFAULTS) do
		local providedId = customAnimations[name]
		local idToUse = providedId or defaultId

		-- Normalize ID (handle number vs string)
		if type(idToUse) == "number" then
			idToUse = "rbxassetid://" .. idToUse
		elseif not string.find(idToUse, "rbxassetid://") then
			-- Assume it might be just the number in string form, unless it's a full URL
			if tonumber(idToUse) then
				idToUse = "rbxassetid://" .. idToUse
			end
		end

		self.AnimationIds[name] = idToUse
	end

	self:_PreloadAnimations()
	self:_BindEvents()

	return self
end

-- // PRIVATE METHODS //

function AnimatedHumanoid:_PreloadAnimations()
	for name, id in pairs(self.AnimationIds) do
		local animObj = Instance.new("Animation")
		animObj.Name = name
		animObj.AnimationId = id

		-- Load the track onto the humanoid
		local success, track = pcall(function()
			return self.Animator:LoadAnimation(animObj)
		end)

		if success and track then
			track.Looped = true

			-- Set Priorities
			if name == "Idle" or name == "Seated" or name == "PlatformStanding" then
				track.Priority = Enum.AnimationPriority.Idle
			elseif name == "Running" or name == "Swimming" or name == "Climbing" then
				track.Priority = Enum.AnimationPriority.Movement
			else
				track.Priority = Enum.AnimationPriority.Action
			end

			-- Dead should not loop usually, but Roblox default often does.
			-- We'll keep it looped to match default behavior or you can set false.
			if name == "Dead" then
				track.Looped = false
			end

			self.Tracks[name] = track

			-- Ensure track is cleaned up (Stopped/Destroyed) when Trove is cleaned
			self._Trove:Add(track)
		else
			warn("[AnimatedHumanoid] Failed to load animation:", name, id)
		end
	end
end

function AnimatedHumanoid:_Play(animName, fadeTime)
	fadeTime = fadeTime or 0.2

	-- Don't restart the same animation
	if self.CurrentTrackName == animName then
		return
	end

	local newTrack = self.Tracks[animName]

	-- Stop the old track
	if self.CurrentTrack then
		self.CurrentTrack:Stop(fadeTime)
	end

	-- Play the new track
	if newTrack then
		newTrack:Play(fadeTime)
		self.CurrentTrack = newTrack
		self.CurrentTrackName = animName
	else
		self.CurrentTrack = nil
		self.CurrentTrackName = ""
	end
end

function AnimatedHumanoid:_BindEvents()
	local hum = self.Humanoid

	-- Running (Handles Walk/Idle)
	self._Trove:Connect(hum.Running, function(speed)
		if speed > 0.1 then
			self:_Play("Running")
		else
			self:_Play("Idle")
		end
	end)

	-- Other States
	self._Trove:Connect(hum.Died, function()
		self:_Play("Dead")
	end)
	self._Trove:Connect(hum.Jumping, function()
		self:_Play("Jumping", 0.1)
	end)
	self._Trove:Connect(hum.Climbing, function()
		self:_Play("Climbing")
	end)
	self._Trove:Connect(hum.GettingUp, function()
		self:_Play("GettingUp")
	end)
	self._Trove:Connect(hum.FreeFalling, function()
		self:_Play("FreeFall")
	end)
	self._Trove:Connect(hum.FallingDown, function()
		self:_Play("FallingDown")
	end)
	self._Trove:Connect(hum.Seated, function()
		self:_Play("Seated")
	end)
	self._Trove:Connect(hum.PlatformStanding, function()
		self:_Play("PlatformStanding")
	end)
	self._Trove:Connect(hum.Swimming, function()
		self:_Play("Swimming")
	end)

	-- Initialize with Idle
	self:_Play("Idle")
end

-- // PUBLIC METHODS //

function AnimatedHumanoid:Destroy()
	self._Trove:Destroy()
end

return AnimatedHumanoid
