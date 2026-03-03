local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Props = require(script.Parent.Props)
local Enums = require(script.Parent.Enums)

local GizmoBehavior = {}

-- Helper function to recursively get all BaseParts from the current selection
local function getActiveParts(objects: { Instance }): { BasePart }
	local parts = {}
	for _, obj in ipairs(objects) do
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end
		for _, desc in ipairs(obj:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(parts, desc)
			end
		end
	end
	return parts
end

-- Calculates an Oriented Bounding Box (OBB) based on a provided base rotation
local function getOrientedBoundingBox(objects: { Instance }, baseRotation: CFrame): (CFrame, Vector3)
	local parts = getActiveParts(objects)
	if #parts == 0 then
		return CFrame.new(), Vector3.new(1, 1, 1)
	end

	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		local size = part.Size / 2
		local cf = part.CFrame

		-- Calculate all 8 corners of the part in World Space
		local corners = {
			cf * Vector3.new(size.X, size.Y, size.Z),
			cf * Vector3.new(-size.X, size.Y, size.Z),
			cf * Vector3.new(size.X, -size.Y, size.Z),
			cf * Vector3.new(-size.X, -size.Y, size.Z),
			cf * Vector3.new(size.X, size.Y, -size.Z),
			cf * Vector3.new(-size.X, size.Y, -size.Z),
			cf * Vector3.new(size.X, -size.Y, -size.Z),
			cf * Vector3.new(-size.X, -size.Y, -size.Z),
		}

		for _, corner in ipairs(corners) do
			-- Convert the World Space corner into the Local Space of our Base Rotation
			local localCorner = baseRotation:PointToObjectSpace(corner)
			minPoint = minPoint:Min(localCorner)
			maxPoint = maxPoint:Max(localCorner)
		end
	end

	-- Size and Center are calculated in the local coordinate space
	local localSize = maxPoint - minPoint
	local localCenter = (minPoint + maxPoint) / 2

	-- Transform the center back to World Space
	local worldCenter = baseRotation:PointToWorldSpace(localCenter)

	-- Return the fully oriented CFrame and the localized size
	return CFrame.new(worldCenter) * baseRotation.Rotation, localSize
end

-- Determines the correct base rotation based on the chosen Tool Axis mode
local function getAxisRotation(selectedObjects: { Instance }): CFrame
	local axisMode = Props.Axis:Get()

	if axisMode == Enums.Axis.Local then
		local activePart = Props.ActivePart:Get()
		if activePart and activePart:IsA("BasePart") then
			return activePart.CFrame.Rotation
		else
			-- Fallback: Use the transform origin or the first selected part
			local transformOrigin = Props.TransformOrigin:Get()
			if transformOrigin and transformOrigin ~= CFrame.new() then
				return transformOrigin.Rotation
			end

			local parts = getActiveParts(selectedObjects)
			if #parts > 0 then
				return parts[1].CFrame.Rotation
			end
		end
	elseif axisMode == Enums.Axis.View then
		local camera = Workspace.CurrentCamera
		if camera then
			return camera.CFrame.Rotation
		end
	end

	-- Default to Global (Identity Rotation)
	return CFrame.new().Rotation
end

function GizmoBehavior.Init(plugin: Plugin, pluginTrove)
	local gizmoFolder = Instance.new("Folder")
	gizmoFolder.Name = "UnifiedScaleGizmo"
	gizmoFolder.Parent = CoreGui
	pluginTrove:Add(gizmoFolder)

	local proxyPart = Instance.new("Part")
	proxyPart.Name = "ScaleBoundingBox"
	proxyPart.Transparency = 1
	proxyPart.Anchored = true
	proxyPart.CanCollide = false
	proxyPart.Parent = gizmoFolder
	pluginTrove:Add(proxyPart)

	local handles = Instance.new("Handles")
	handles.Style = Enum.HandlesStyle.Resize
	handles.Color3 = Props.ActiveColor:Get() or Color3.fromRGB(13, 105, 172)
	handles.Adornee = proxyPart
	handles.Parent = gizmoFolder
	pluginTrove:Add(handles)

	local initialStates = {}
	local initialBoxCFrame = CFrame.new()
	local initialBoxSize = Vector3.new()
	local activeParts = {}
	local isDragging = false

	local partsBatch = {}
	local cframesBatch = {}

	local function updateGizmo()
		if isDragging then
			return
		end

		-- Check if the gizmo is explicitly requested to be hidden
		local hideGizmos = Props.HideGizmos:Get()
		if hideGizmos then
			handles.Visible = false
			return -- Exit early, no need to do expensive math if it's hidden!
		end

		local currentTool = Props.Tool:Get()
		local selectedObjects = Props.SelectedObjects:Get()

		if currentTool == Enums.Tools.Scale and #selectedObjects > 0 then
			-- Calculate rotation constraint based on Local/Global/View
			local baseRotation = getAxisRotation(selectedObjects)

			local boxCFrame, boxSize = getOrientedBoundingBox(selectedObjects, baseRotation)

			if boxSize.Magnitude > 0 then
				proxyPart.CFrame = boxCFrame
				proxyPart.Size = boxSize
				handles.Visible = true
			else
				handles.Visible = false
			end
		else
			handles.Visible = false
		end
	end

	pluginTrove:Add(RunService.RenderStepped:Connect(updateGizmo))
	pluginTrove:Add(Props.Tool:Observe(updateGizmo))
	pluginTrove:Add(Props.SelectedObjects:Observe(updateGizmo))
	pluginTrove:Add(Props.Axis:Observe(updateGizmo)) -- Re-orient when Axis changes
	pluginTrove:Add(Props.HideGizmos:Observe(updateGizmo)) -- Added our new HideGizmos observer

	pluginTrove:Add(Props.ActiveColor:Observe(function(color)
		handles.Color3 = color
	end))

	pluginTrove:Add(handles.MouseButton1Down:Connect(function()
		isDragging = true

		local selectedObjects = Props.SelectedObjects:Get()
		local baseRotation = getAxisRotation(selectedObjects)
		initialBoxCFrame, initialBoxSize = getOrientedBoundingBox(selectedObjects, baseRotation)
		activeParts = getActiveParts(selectedObjects)

		table.clear(initialStates)
		for _, part in ipairs(activeParts) do
			initialStates[part] = {
				CFrame = part.CFrame,
				Size = part.Size,
				PivotOffset = part.PivotOffset,
			}
		end
	end))

	pluginTrove:Add(handles.MouseButton1Up:Connect(function()
		isDragging = false
		updateGizmo()
		ChangeHistoryService:SetWaypoint("Scaled Objects")
	end))

	pluginTrove:Add(handles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
		local isAltDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
		local isCtrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

		local faceNormal = Vector3.FromNormalId(face)
		local deltaVector = faceNormal * distance
		local sizeChange = Vector3.new(math.abs(deltaVector.X), math.abs(deltaVector.Y), math.abs(deltaVector.Z))

		if distance < 0 then
			sizeChange = -sizeChange
		end

		if isCtrlDown then
			sizeChange *= 2
		end

		local newBoxSize = initialBoxSize + sizeChange

		if isAltDown then
			local dragAxis = Vector3.new(math.abs(faceNormal.X), math.abs(faceNormal.Y), math.abs(faceNormal.Z))
			local scaleFactor = 1

			if dragAxis.X == 1 and initialBoxSize.X > 0 then
				scaleFactor = newBoxSize.X / initialBoxSize.X
			elseif dragAxis.Y == 1 and initialBoxSize.Y > 0 then
				scaleFactor = newBoxSize.Y / initialBoxSize.Y
			elseif dragAxis.Z == 1 and initialBoxSize.Z > 0 then
				scaleFactor = newBoxSize.Z / initialBoxSize.Z
			end

			newBoxSize = initialBoxSize * scaleFactor
		end

		local minSize = 0.001
		newBoxSize = Vector3.new(
			math.max(minSize, newBoxSize.X),
			math.max(minSize, newBoxSize.Y),
			math.max(minSize, newBoxSize.Z)
		)

		local actualDeltaSize = newBoxSize - initialBoxSize

		-- Center shift calculation (relative to the bounding box's local space)
		local localCenterShift = (actualDeltaSize * faceNormal) / 2

		-- Convert local center shift to world space using the bounding box's rotation
		local worldCenterShift = initialBoxCFrame:VectorToWorldSpace(localCenterShift)

		local newBoxCenter = initialBoxCFrame.Position
		if not isCtrlDown then
			newBoxCenter += worldCenterShift
		end

		local newBoxCFrame = CFrame.new(newBoxCenter) * initialBoxCFrame.Rotation

		proxyPart.Size = newBoxSize
		proxyPart.CFrame = newBoxCFrame

		-- Scale multiplier representing scale factor along the Bounding Box's local axes
		local boxScaleMultiplier = Vector3.new(
			initialBoxSize.X > minSize and (newBoxSize.X / initialBoxSize.X) or 1,
			initialBoxSize.Y > minSize and (newBoxSize.Y / initialBoxSize.Y) or 1,
			initialBoxSize.Z > minSize and (newBoxSize.Z / initialBoxSize.Z) or 1
		)

		table.clear(partsBatch)
		table.clear(cframesBatch)

		for part, state in pairs(initialStates) do
			-- 1. Position Calculation:
			-- Convert part pos to box's local space, scale it, return to world space
			local localRelativePos = initialBoxCFrame:PointToObjectSpace(state.CFrame.Position)
			local scaledRelativePos = localRelativePos * boxScaleMultiplier
			local newWorldPos = newBoxCFrame:PointToWorldSpace(scaledRelativePos)
			local targetCFrame = CFrame.new(newWorldPos) * state.CFrame.Rotation

			-- 2. Size Calculation:
			-- To avoid shearing, project the part's axes into the bounding box's local space
			local localRight = initialBoxCFrame:VectorToObjectSpace(state.CFrame.RightVector)
			local localUp = initialBoxCFrame:VectorToObjectSpace(state.CFrame.UpVector)
			local localLook = initialBoxCFrame:VectorToObjectSpace(state.CFrame.LookVector)

			local localScaleX = (localRight * boxScaleMultiplier).Magnitude
			local localScaleY = (localUp * boxScaleMultiplier).Magnitude
			local localScaleZ = (localLook * boxScaleMultiplier).Magnitude
			local partScaleMultiplier = Vector3.new(localScaleX, localScaleY, localScaleZ)

			part.Size = state.Size * partScaleMultiplier

			-- 3. PivotOffset Calculation
			local newPivotOffset = CFrame.new(state.PivotOffset.Position * partScaleMultiplier)
				* state.PivotOffset.Rotation
			part.PivotOffset = newPivotOffset

			table.insert(partsBatch, part)
			table.insert(cframesBatch, targetCFrame)
		end

		Workspace:BulkMoveTo(partsBatch, cframesBatch, Enum.BulkMoveMode.FireCFrameChanged)
	end))
end

return GizmoBehavior
