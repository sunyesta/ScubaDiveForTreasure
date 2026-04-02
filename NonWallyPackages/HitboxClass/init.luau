--[[
Enhanced HitboxClass Module v2.0
Optimized for server-side performance with advanced features

HitMode behavior:
- "Weak" (default): Fires OnHit once per character, on the first part hit.
- "Strong": Fires OnHit for every part hit on the same character.
- "Cooldown": Fires OnHit once per character, then ignores further hits on that character until the cooldown (HitCooldown, default 1 second) expires.

HitboxType options:
- "Box": Single box overlap at specified CFrame/Position/Part with given size (or proportional if opts.proportional provided).
- "Ball": Single sphere overlap at specified CFrame/Position/Part with given radius (or proportional if opts.proportional provided).
- "InPart": Uses an actual BasePart for precise collision detection.
- "Magnitude": Distance-based detection from a source point.
- "Cylinder": Cylindrical detection area.
- "TimedBox": Box overlap repeated over duration with interval at specified CFrame/Position/Part (proportional supported).
- "TimedBall": Sphere overlap repeated over duration with interval at specified CFrame/Position/Part (proportional supported).
- "WeldedBox": Box overlap welded to root BasePart, updated continuously over duration with interval (proportional supported).
- "WeldedBall": Sphere overlap welded to root BasePart, updated continuously over duration with interval (proportional supported).

Enhanced Opts table:
- root (BasePart/CFrame/Vector3): Required for all types; if opts.proportional is provided, root must be BasePart.
- size (Vector3): Size of box or diameter vector for sphere (use size.X for radius * 2). Ignored if opts.proportional is provided.
- duration (number): Duration in seconds for timed/welded hitboxes. Not used for Box/Ball types.
- interval (number): Interval in seconds between repeated queries (default 0.05). Not used for Box/Ball types.
- overlapParams (OverlapParams): Custom overlap parameters for spatial queries.
- debug (boolean): Whether to enable debug drawing.
- HitMode (string): "Weak" (default), "Strong", or "Cooldown".
- HitCooldown (number): Cooldown seconds for "Cooldown" mode (default 1).
- IgnoreCharacters (table): Array of Models to ignore (OnHit will not fire for these).
- proportional (table or nil): If present, enables proportional sizing and offset.
    - scaleMultiplier (Vector3): Multiplier for size scaling.
    - offsetMultiplier (number): Multiplier for offset distance.

NEW FEATURES:
- velocityPrediction (boolean): Predicts target movement for moving hitboxes (default false).
- velocityMultiplier (number): Multiplier for velocity prediction (default 6).
- dotProductFilter (table): Directional filtering based on dot product.
    - dotProduct (number): Minimum dot product required (-1 to 1).
    - referenceVector (Vector3): Reference direction vector.
    - sourcePosition (Vector3/BasePart): Source position for direction calculation.
- blacklistParts (table): Array of BaseParts to ignore for granular filtering.
- hitboxId (string/number): Optional ID for tracking and cleanup.

Usage:
Create with HitboxClass.new(HitboxType, opts), then call :Start() to begin detection.
Listen to OnHit event: OnHit:Connect(function(characterModel, hitPart) ... end)
Call :Destroy() to stop and clean up.

--]]

local RunService = game:GetService("RunService")
local SpatialHitbox = require(script.SpatialHitbox)
local GoodSignal = require(script.GoodSignal)

local HitboxClass = {}
HitboxClass.__index = HitboxClass

-- Global registry for ID-based cleanup (lightweight alternative to cache)
local HitboxRegistry = {}

-- Utility: Enhanced blacklist checking
local function isBlacklisted(model, part, ignoreChars, blacklistParts)
	-- Check character blacklist
	if ignoreChars then
		for _, ignoredChar in ipairs(ignoreChars) do
			if model == ignoredChar then
				return true
			end
		end
	end

	-- Check part blacklist
	if blacklistParts then
		for _, blacklistedPart in ipairs(blacklistParts) do
			if part == blacklistedPart or part:IsDescendantOf(blacklistedPart) then
				return true
			end
		end
	end

	return false
end

-- Utility: Dot product filtering
local function passesDotProductFilter(model, filter)
	if not filter then
		return true
	end

	local sourcePos = filter.sourcePosition
	if typeof(sourcePos) == "Instance" and sourcePos:IsA("BasePart") then
		sourcePos = sourcePos.Position
	end

	local targetPos = model.PrimaryPart and model.PrimaryPart.Position
	if not targetPos or not sourcePos then
		return true
	end

	local directionToTarget = (targetPos - sourcePos).Unit
	local dotProduct = directionToTarget:Dot(filter.referenceVector.Unit)

	return dotProduct >= filter.dotProduct
end

-- Utility: Velocity prediction
local function applyVelocityPrediction(cframe, root, velocityMultiplier)
	if not root or not root:IsA("BasePart") then
		return cframe
	end

	local velocity = root.AssemblyLinearVelocity
	if velocity.Magnitude < 1 then
		return cframe
	end -- Skip if barely moving

	local prediction = velocity / (velocityMultiplier or 6)
	return cframe * CFrame.new(prediction)
end

-- Helper: get CFrame from source (BasePart, CFrame, Vector3)
local function getCFrameFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.CFrame
		end
	elseif typeof(source) == "CFrame" then
		return source
	elseif typeof(source) == "Vector3" then
		return CFrame.new(source)
	end
	return nil
end

-- Helper: get Position from source (BasePart, CFrame, Vector3)
local function getPositionFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.Position
		end
	elseif typeof(source) == "CFrame" then
		return source.Position
	elseif typeof(source) == "Vector3" then
		return source
	end
	return nil
end

-- Helper: calculate proportional size and offset based on root and opts.proportional
local function proportionalData(root, proportionalOpts)
	local scale = proportionalOpts.scaleMultiplier or Vector3.new(2.5, 1.8, 2.2)
	local offsetMult = proportionalOpts.offsetMultiplier or 1.5

	local rSize = root.Size
	local baseRadius = (rSize.X + rSize.Z) / 2

	local size = Vector3.new(baseRadius * scale.X, rSize.Y * scale.Y, baseRadius * scale.Z)

	local offsetDistance = -math.max(rSize.Z, rSize.X) * offsetMult
	local offsetCFrame = CFrame.new(0, 0, offsetDistance)

	return size, offsetCFrame
end

local function getCharacterFromPart(part)
	if not part then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

function HitboxClass.new(HitboxType, opts)
	opts = opts or {}

	local self = setmetatable({}, HitboxClass)
	self.HitboxType = HitboxType or "Box"

	-- Enhanced opts with new features
	self.Opts = {
		root = opts.root,
		size = opts.size,
		duration = opts.duration,
		interval = opts.interval or 0.05,
		overlapParams = opts.overlapParams,
		debug = opts.debug,
		HitMode = opts.HitMode or "Weak",
		HitCooldown = opts.HitCooldown or 1,
		IgnoreCharacters = opts.IgnoreCharacters or {},
		proportional = opts.proportional,

		-- NEW ENHANCED FEATURES
		velocityPrediction = opts.velocityPrediction or false,
		velocityMultiplier = opts.velocityMultiplier or 6,
		dotProductFilter = opts.dotProductFilter, -- {dotProduct, referenceVector, sourcePosition}
		blacklistParts = opts.blacklistParts or {},
		hitboxId = opts.hitboxId,
	}

	self.OnHit = GoodSignal.new()

	self.HitMode = self.Opts.HitMode
	self.HitCooldown = self.Opts.HitCooldown

	self._hitCache = {}
	self._running = false
	self._conn = nil

	-- Create a lookup set for IgnoreCharacters for fast check
	self._ignoreSet = {}
	for _, model in ipairs(self.Opts.IgnoreCharacters) do
		self._ignoreSet[model] = true
	end

	-- Register hitbox by ID for cleanup
	if self.Opts.hitboxId then
		if not HitboxRegistry[self.Opts.hitboxId] then
			HitboxRegistry[self.Opts.hitboxId] = {}
		end
		table.insert(HitboxRegistry[self.Opts.hitboxId], self)
	end

	return self
end

function HitboxClass:_cleanCooldownCache()
	if self.HitMode ~= "Cooldown" or not self._hitCache then
		return
	end
	local now = tick()
	for model, lastHitTime in pairs(self._hitCache) do
		if now - lastHitTime >= self.HitCooldown then
			self._hitCache[model] = nil
		end
	end
end

function HitboxClass:_shouldIgnoreCharacter(model)
	return self._ignoreSet and self._ignoreSet[model] == true
end

function HitboxClass:_processHit(model, part)
	if not model or not part then
		return
	end

	-- Enhanced blacklist checking
	if isBlacklisted(model, part, self.Opts.IgnoreCharacters, self.Opts.blacklistParts) then
		return
	end

	-- Legacy ignore check (for compatibility)
	if self:_shouldIgnoreCharacter(model) then
		return
	end

	-- Dot product filtering
	if not passesDotProductFilter(model, self.Opts.dotProductFilter) then
		return
	end

	-- Don't process hits if OnHit signal is nil (hitbox destroyed)
	if not self.OnHit then
		return
	end

	if self.HitMode == "Strong" then
		self.OnHit:Fire(model, part)
		return
	end

	if self.HitMode == "Weak" then
		if self._hitCache and self._hitCache[model] then
			return
		end
		if self._hitCache then
			self._hitCache[model] = true
		end
		self.OnHit:Fire(model, part)
		return
	end

	if self.HitMode == "Cooldown" then
		if not self._hitCache then
			-- If hitCache is nil, just fire the hit (no cooldown tracking)
			self.OnHit:Fire(model, part)
			return
		end
		local now = tick()
		local lastHit = self._hitCache[model]
		if lastHit and now - lastHit < self.HitCooldown then
			return
		end
		self._hitCache[model] = now
		self.OnHit:Fire(model, part)
		return
	end
end

function HitboxClass:_queryAndProcess()
	if not self._running then
		return
	end

	local parts = {}

	local opts = self.Opts
	local root = opts.root
	local size = opts.size
	local duration = opts.duration
	local interval = opts.interval
	local overlapParams = opts.overlapParams
	local debug = opts.debug
	local proportional = opts.proportional

	if not root then
		warn("[HitboxClass] opts.root is required")
		return
	end

	local useProportional = proportional ~= nil
	local querySize, queryCFrame, queryPos, queryRadius

	-- Handle proportional sizing (requires BasePart root)
	if useProportional then
		if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
			warn("[HitboxClass] opts.root must be a BasePart when using proportional sizing")
			return
		end
		local localOffset
		querySize, localOffset = proportionalData(root, proportional)
		queryCFrame = root.CFrame * localOffset
		queryPos = queryCFrame.Position
		queryRadius = querySize.X / 2
	else
		-- Get CFrame and Position from source
		queryCFrame = getCFrameFromSource(root)
		queryPos = getPositionFromSource(root)

		if not queryCFrame or not queryPos then
			warn("[HitboxClass] Invalid root source type")
			return
		end

		querySize = size
		queryRadius = size and (size.X / 2) or nil
	end

	-- Apply velocity prediction if enabled
	if self.Opts.velocityPrediction and queryCFrame then
		queryCFrame = applyVelocityPrediction(queryCFrame, root, self.Opts.velocityMultiplier)
		queryPos = queryCFrame.Position
	end

	-- Handle different hitbox types
	if self.HitboxType == "Box" then
		if not querySize then
			warn("[HitboxClass] size is required for Box hitbox")
			return
		end
		parts = SpatialHitbox.Box(queryCFrame, querySize, overlapParams, debug)
	elseif self.HitboxType == "Ball" then
		if not queryRadius then
			warn("[HitboxClass] size is required for Ball hitbox")
			return
		end
		parts = SpatialHitbox.Ball(queryPos, queryRadius, overlapParams, debug)
	elseif self.HitboxType == "InPart" then
		if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
			warn("[HitboxClass] opts.root must be a BasePart for InPart hitbox")
			return
		end
		parts = SpatialHitbox.InPart(root, overlapParams, debug)
	elseif self.HitboxType == "Magnitude" then
		if not queryRadius then
			warn("[HitboxClass] size is required for Magnitude hitbox")
			return
		end
		-- For magnitude, we need to get all parts in the area first, then filter by distance
		local allParts = SpatialHitbox.Ball(queryPos, queryRadius, overlapParams, false) -- No debug for intermediate query
		parts = SpatialHitbox.Magnitude(queryPos, allParts, queryRadius, debug)
	elseif self.HitboxType == "Cylinder" then
		if not queryRadius or not querySize then
			warn("[HitboxClass] size (for height) and radius are required for Cylinder hitbox")
			return
		end
		local height = typeof(querySize) == "Vector3" and querySize.Y or querySize
		parts = SpatialHitbox.Cylinder(queryCFrame, queryRadius, height, overlapParams, debug)
	elseif self.HitboxType == "TimedBox" then
		if not querySize or not duration then
			warn("[HitboxClass] size and duration are required for TimedBox hitbox")
			return
		end
		-- For TimedBox, we'll use the regular Box function and let the heartbeat handle timing
		parts = SpatialHitbox.Box(queryCFrame, querySize, overlapParams, debug)
	elseif self.HitboxType == "TimedBall" then
		if not queryRadius or not duration then
			warn("[HitboxClass] size and duration are required for TimedBall hitbox")
			return
		end
		-- For TimedBall, we'll use the regular Ball function and let the heartbeat handle timing
		parts = SpatialHitbox.Ball(queryPos, queryRadius, overlapParams, debug)
	elseif self.HitboxType == "WeldedBox" then
		if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
			warn("[HitboxClass] opts.root must be a BasePart for WeldedBox hitbox")
			return
		end
		if not querySize or not duration then
			warn("[HitboxClass] size and duration are required for WeldedBox hitbox")
			return
		end
		-- For WeldedBox, get current CFrame from root each frame
		local currentCFrame = root.CFrame
		if useProportional then
			local localOffset
			querySize, localOffset = proportionalData(root, proportional)
			currentCFrame = currentCFrame * localOffset
		end
		-- Apply velocity prediction for welded hitboxes
		if self.Opts.velocityPrediction then
			currentCFrame = applyVelocityPrediction(currentCFrame, root, self.Opts.velocityMultiplier)
		end
		parts = SpatialHitbox.Box(currentCFrame, querySize, overlapParams, debug)
	elseif self.HitboxType == "WeldedBall" then
		if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
			warn("[HitboxClass] opts.root must be a BasePart for WeldedBall hitbox")
			return
		end
		if not queryRadius or not duration then
			warn("[HitboxClass] size and duration are required for WeldedBall hitbox")
			return
		end
		-- For WeldedBall, get current Position from root each frame
		local currentPos = root.Position
		if useProportional then
			local localOffset
			querySize, localOffset = proportionalData(root, proportional)
			currentPos = (root.CFrame * localOffset).Position
		end
		-- Apply velocity prediction for welded hitboxes
		if self.Opts.velocityPrediction then
			local currentCFrame = CFrame.new(currentPos)
			currentCFrame = applyVelocityPrediction(currentCFrame, root, self.Opts.velocityMultiplier)
			currentPos = currentCFrame.Position
		end
		parts = SpatialHitbox.Ball(currentPos, queryRadius, overlapParams, debug)
	else
		warn("[HitboxClass] Unsupported HitboxType:", self.HitboxType)
		return
	end

	self:_cleanCooldownCache()

	if self.HitMode == "Strong" then
		for _, part in ipairs(parts) do
			local model = getCharacterFromPart(part)
			if model then
				self:_processHit(model, part)
			end
		end
		return
	end

	local seenModels = {}
	for _, part in ipairs(parts) do
		local model = getCharacterFromPart(part)
		if model and not seenModels[model] then
			seenModels[model] = true
			self:_processHit(model, part)
		end
	end
end

function HitboxClass:Start()
	if self._running then
		return
	end
	self._running = true

	-- Box and Ball types execute only once
	if self.HitboxType == "Box" or self.HitboxType == "Ball" then
		self:_queryAndProcess()
		self:Destroy()
		return
	end

	-- Timed and Welded types require duration and use heartbeat loop
	local duration = self.Opts.duration
	if not duration or duration <= 0 then
		warn("[HitboxClass] duration is required for " .. self.HitboxType .. " hitbox")
		self:Destroy()
		return
	end

	local interval = self.Opts.interval
	local startTime = tick()
	local accumulatedTime = 0

	self._conn = RunService.Heartbeat:Connect(function(dt)
		if not self._running then
			self._conn:Disconnect()
			self._conn = nil
			return
		end

		accumulatedTime = accumulatedTime + dt
		if accumulatedTime >= interval then
			accumulatedTime = 0
			self:_queryAndProcess()
		end

		if tick() - startTime >= duration then
			self:Destroy()
		end
	end)
end

function HitboxClass:Destroy()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	self._running = false
	self._hitCache = {}
	if self.OnHit then
		self.OnHit:DisconnectAll()
		self.OnHit = nil
	end

	-- Remove from registry
	if self.Opts and self.Opts.hitboxId then
		local registry = HitboxRegistry[self.Opts.hitboxId]
		if registry then
			for i, hitbox in ipairs(registry) do
				if hitbox == self then
					table.remove(registry, i)
					break
				end
			end
			-- Clean up empty registry entries
			if #registry == 0 then
				HitboxRegistry[self.Opts.hitboxId] = nil
			end
		end
	end

	self.Opts = nil
	self._ignoreSet = nil
end

-- Static method: Cleanup all hitboxes with a specific ID
function HitboxClass.ClearHitboxesWithId(hitboxId)
	local hitboxes = HitboxRegistry[hitboxId]
	if not hitboxes then
		return 0
	end

	local count = #hitboxes
	for _, hitbox in ipairs(hitboxes) do
		pcall(function()
			hitbox:Destroy()
		end)
	end
	HitboxRegistry[hitboxId] = nil

	return count
end

-- Static method: Get all active hitboxes by ID
function HitboxClass.GetHitboxesWithId(hitboxId)
	return HitboxRegistry[hitboxId] or {}
end

-- Static method: Get total active hitboxes count
function HitboxClass.GetActiveHitboxCount()
	local total = 0
	for _, hitboxes in pairs(HitboxRegistry) do
		total = total + #hitboxes
	end
	return total
end

-- Static method: Clear all active hitboxes (emergency cleanup)
function HitboxClass.ClearAllHitboxes()
	local count = 0
	for hitboxId, hitboxes in pairs(HitboxRegistry) do
		for _, hitbox in ipairs(hitboxes) do
			pcall(function()
				hitbox:Destroy()
			end)
			count = count + 1
		end
	end
	HitboxRegistry = {}
	return count
end

return HitboxClass
