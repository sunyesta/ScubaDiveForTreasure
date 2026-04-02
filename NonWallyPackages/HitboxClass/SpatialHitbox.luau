local SpatialHitbox = {}
local DEFAULT_FOLDER = workspace:FindFirstChild("LivingThings") or workspace

local function ensureOverlapParams(supplied)
	if supplied then
		return supplied
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { DEFAULT_FOLDER }
	params.RespectCanCollide = false

	return params
end

local function ensureRaycastParams(supplied)
	if supplied then
		return supplied
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { DEFAULT_FOLDER }
	params.RespectCanCollide = false

	return params
end

local function createAdorno(parent, class, props)
	local adorno = Instance.new(class)
	for k, v in pairs(props) do
		adorno[k] = v
	end
	adorno.Parent = parent
	return adorno
end

local function autoDestroy(adorno, lifetime)
	task.delay(lifetime or 0.25, function()
		if adorno and adorno.Parent then
			adorno:Destroy()
		end
	end)
end

-- Helper: get CFrame from source (BasePart, Attachment, CFrame, Vector3)
local function getCFrameFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.CFrame
		elseif source:IsA("Attachment") then
			return source.WorldCFrame
		end
	elseif typeof(source) == "CFrame" then
		return source
	elseif typeof(source) == "Vector3" then
		return CFrame.new(source)
	end
	return nil
end

-- Helper: get Position from source (BasePart, Attachment, CFrame, Vector3)
local function getPositionFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.Position
		elseif source:IsA("Attachment") then
			return source.WorldPosition
		end
	elseif typeof(source) == "CFrame" then
		return source.Position
	elseif typeof(source) == "Vector3" then
		return source
	end
	return nil
end

------------------------------------------------------------------
-- 1) INSTANT QUERIES
------------------------------------------------------------------

function SpatialHitbox.Box(cframe, size, overlapParams, debug)
	if debug then
		local adorno = createAdorno(workspace, "BoxHandleAdornment", {
			CFrame = cframe,
			Size = size,
			Color3 = Color3.new(1, 0, 1),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	return workspace:GetPartBoundsInBox(cframe, size, ensureOverlapParams(overlapParams))
end

function SpatialHitbox.Radius(position, radius, overlapParams, debug)
	if debug then
		local adorno = createAdorno(workspace, "SphereHandleAdornment", {
			CFrame = CFrame.new(position),
			Radius = radius,
			Color3 = Color3.new(0, 1, 1),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	return workspace:GetPartBoundsInRadius(position, radius, ensureOverlapParams(overlapParams))
end

-- Alias for Ball hitbox type
SpatialHitbox.Ball = SpatialHitbox.Radius

-- Enhanced: InPart spatial query using actual part
function SpatialHitbox.InPart(part, overlapParams, debug)
	if not part or not part:IsA("BasePart") then
		warn("[SpatialHitbox.InPart] Invalid part provided")
		return {}
	end

	if debug then
		local adorno = createAdorno(workspace, "BoxHandleAdornment", {
			CFrame = part.CFrame,
			Size = part.Size,
			Color3 = Color3.new(0, 1, 0),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	return workspace:GetPartsInPart(part, ensureOverlapParams(overlapParams))
end

-- Enhanced: Magnitude-based distance check (like public implementation)
function SpatialHitbox.Magnitude(sourcePos, targetParts, maxDistance, debug)
	if typeof(sourcePos) == "Instance" and sourcePos:IsA("BasePart") then
		sourcePos = sourcePos.Position
	elseif typeof(sourcePos) == "CFrame" then
		sourcePos = sourcePos.Position
	end

	if debug then
		local adorno = createAdorno(workspace, "SphereHandleAdornment", {
			CFrame = CFrame.new(sourcePos),
			Radius = maxDistance,
			Color3 = Color3.new(1, 0.5, 0),
			Transparency = 0.7,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	local validParts = {}
	for _, part in ipairs(targetParts) do
		if part and part:IsA("BasePart") then
			local distance = (sourcePos - part.Position).Magnitude
			if distance <= maxDistance then
				table.insert(validParts, part)
			end
		end
	end

	return validParts
end

function SpatialHitbox.Cylinder(baseCFrame, radius, height, overlapParams, debug)
	local tempPart = Instance.new("Part")
	tempPart.Shape = Enum.PartType.Cylinder
	tempPart.Anchored = true
	tempPart.CanCollide = false
	tempPart.Transparency = 1
	tempPart.Size = Vector3.new(radius * 2, height, radius * 2)
	tempPart.CFrame = baseCFrame * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	tempPart.Parent = workspace

	local params = ensureOverlapParams(overlapParams)
	local parts = tempPart:GetTouchingParts()

	local filteredParts = {}
	for _, part in ipairs(parts) do
		if params.FilterType == Enum.RaycastFilterType.Include then
			local include = false
			for _, inst in ipairs(params.FilterDescendantsInstances) do
				if part:IsDescendantOf(inst) then
					include = true
					break
				end
			end
			if not include then
				continue
			end
		elseif params.FilterType == Enum.RaycastFilterType.Exclude then
			local exclude = false
			for _, inst in ipairs(params.FilterDescendantsInstances) do
				if part:IsDescendantOf(inst) then
					exclude = true
					break
				end
			end
			if exclude then
				continue
			end
		end
		if params.RespectCanCollide and not part.CanCollide then
			continue
		end
		table.insert(filteredParts, part)
	end

	if debug then
		local adorno = createAdorno(workspace, "CylinderHandleAdornment", {
			CFrame = tempPart.CFrame,
			Radius = radius,
			Height = height,
			Color3 = Color3.new(1, 1, 0),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	tempPart:Destroy()

	return filteredParts
end

function SpatialHitbox.Raycast(origin, direction, rayParams, debug)
	local params = ensureRaycastParams(rayParams)
	local result = workspace:Raycast(origin, direction, params)

	if debug then
		local adorno = createAdorno(workspace, "LineHandleAdornment", {
			CFrame = CFrame.new(origin, origin + direction),
			Length = direction.Magnitude,
			Thickness = 2,
			Color3 = result and Color3.new(0, 1, 0) or Color3.new(1, 0, 0),
			Adornee = workspace.Terrain,
			AlwaysOnTop = true,
			ZIndex = 10,
		})
		autoDestroy(adorno, 1)
	end

	return result
end

------------------------------------------------------------------
-- 2) TIMED QUERIES
------------------------------------------------------------------

local function timedQuery(queryFunc, duration, interval, debugAdorn, overlapParams)
	local results = {}
	local endTime = os.clock() + duration
	interval = interval or 0.1

	if debugAdorn then
		debugAdorn.Parent = workspace.Terrain
	end

	while os.clock() < endTime do
		for _, part in ipairs(queryFunc()) do
			results[part] = true
		end
		task.wait(interval)
	end

	if debugAdorn then
		debugAdorn:Destroy()
	end

	return results
end

function SpatialHitbox.BoxTimed(source, size, duration, interval, overlapParams, debug)
	local adorno
	local cf = getCFrameFromSource(source)
	if not cf then
		warn("[SpatialHitbox.BoxTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "BoxHandleAdornment", {
			Size = size,
			Color3 = Color3.new(1, 0, 1),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = cf
		end
		return workspace:GetPartBoundsInBox(cf, size, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.1, adorno, overlapParams)
end

function SpatialHitbox.RadiusTimed(source, radius, duration, interval, overlapParams, debug)
	local adorno
	local pos = getPositionFromSource(source)
	if not pos then
		warn("[SpatialHitbox.RadiusTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "SphereHandleAdornment", {
			Radius = radius,
			Color3 = Color3.new(0, 1, 1),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = CFrame.new(pos)
		end
		return workspace:GetPartBoundsInRadius(pos, radius, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.1, adorno, overlapParams)
end

function SpatialHitbox.WeldedBoxTimed(source, size, duration, interval, overlapParams, debug)
	local adorno
	local cf = getCFrameFromSource(source)
	if not cf then
		warn("[SpatialHitbox.WeldedBoxTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "BoxHandleAdornment", {
			Size = size,
			Color3 = Color3.new(1, 0.5, 0),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = cf
		end
		return workspace:GetPartBoundsInBox(cf, size, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.05, adorno, overlapParams)
end

function SpatialHitbox.WeldedRadiusTimed(source, radius, duration, interval, overlapParams, debug)
	local adorno
	local pos = getPositionFromSource(source)
	if not pos then
		warn("[SpatialHitbox.WeldedRadiusTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "SphereHandleAdornment", {
			Radius = radius,
			Color3 = Color3.new(0, 1, 1),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = CFrame.new(pos)
		end
		return workspace:GetPartBoundsInRadius(pos, radius, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.1, adorno, overlapParams)
end

-- Alias for WeldedBall hitbox type
SpatialHitbox.WeldedBallTimed = SpatialHitbox.WeldedRadiusTimed

function SpatialHitbox.WeldedCylinderTimed(source, radius, height, duration, interval, overlapParams, debug)
	local adorno
	local cf = getCFrameFromSource(source)
	if not cf then
		warn("[SpatialHitbox.WeldedCylinderTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "CylinderHandleAdornment", {
			Radius = radius,
			Height = height,
			Color3 = Color3.new(1, 1, 0),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		end

		local tempPart = Instance.new("Part")
		tempPart.Shape = Enum.PartType.Cylinder
		tempPart.Anchored = true
		tempPart.CanCollide = false
		tempPart.Transparency = 1
		tempPart.Size = Vector3.new(radius * 2, height, radius * 2)
		tempPart.CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		tempPart.Parent = workspace

		local params = ensureOverlapParams(overlapParams)
		local parts = tempPart:GetTouchingParts()

		local filteredParts = {}
		for _, part in ipairs(parts) do
			if params.FilterType == Enum.RaycastFilterType.Include then
				local include = false
				for _, inst in ipairs(params.FilterDescendantsInstances) do
					if part:IsDescendantOf(inst) then
						include = true
						break
					end
				end
				if not include then
					continue
				end
			elseif params.FilterType == Enum.RaycastFilterType.Exclude then
				local exclude = false
				for _, inst in ipairs(params.FilterDescendantsInstances) do
					if part:IsDescendantOf(inst) then
						exclude = true
						break
					end
				end
				if exclude then
					continue
				end
			end
			if params.RespectCanCollide and not part.CanCollide then
				continue
			end
			table.insert(filteredParts, part)
		end

		tempPart:Destroy()
		return filteredParts
	end, duration, interval or 0.05, adorno, overlapParams)
end

return SpatialHitbox
