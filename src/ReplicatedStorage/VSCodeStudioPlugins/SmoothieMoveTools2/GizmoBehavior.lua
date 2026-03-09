local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Props = require(script.Parent.Props)
local Enums = require(script.Parent.Enums)

local PRECISION_MULTIPLIER = 0.1

local GizmoBehavior = {}

-- Utility function to snap values strictly to the grid interval
local function SnapToGrid(value: number, step: number): number
	if step <= 0 then
		return value
	end
	return math.round(value / step) * step
end

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
	handles.Color3 = Color3.fromRGB(0, 255, 34)
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

		local hideGizmos = Props.HideGizmos:Get()
		if hideGizmos then
			handles.Visible = false
			return
		end

		local currentTool = Props.Tool:Get()
		local selectedObjects = Props.SelectedObjects:Get()

		if currentTool == Enums.Tools.Scale and #selectedObjects > 0 then
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
	pluginTrove:Add(Props.Axis:Observe(updateGizmo))
	pluginTrove:Add(Props.HideGizmos:Observe(updateGizmo))

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
		local isPrecision = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		local useSnapping = Props.UseSnapping:Get()
		local snappingMode = Props.SnappingMode:Get()
		local moveStep = Props.MoveStudsIncrement:Get()
		local isGridSnap = false

		if useSnapping and snappingMode == Enums.SnappingMode.Grid then
			moveStep = Props.GridSize:Get()
			isGridSnap = true
		end

		if isPrecision then
			distance *= PRECISION_MULTIPLIER
			if moveStep > 0 then
				moveStep *= PRECISION_MULTIPLIER
			end
		end

		-- Calculate Normal directions
		local faceNormal = Vector3.FromNormalId(face)
		local worldNormal = initialBoxCFrame:VectorToWorldSpace(faceNormal)

		local targetDistance = distance

		if moveStep > 0 then
			if isGridSnap then
				-- ABSOLUTE GRID SNAPPING: Force endpoints to sit perfectly on grid intersections

				-- 1. Find where the moving face currently is in World Space
				local localFaceOffset = faceNormal * (initialBoxSize / 2)
				local initialWorldFaceCenter = initialBoxCFrame:PointToWorldSpace(localFaceOffset)

				-- 2. Find where the mouse is attempting to pull the face to in World Space
				local draggedWorldFaceCenter = initialWorldFaceCenter + (worldNormal * distance)

				-- 3. Snap the target World Space position to our grid, but only apply it
				-- to the axes that correspond to the normal direction we are pulling.
				local snappedWorldX = math.abs(worldNormal.X) > 0.001 and SnapToGrid(draggedWorldFaceCenter.X, moveStep)
					or draggedWorldFaceCenter.X
				local snappedWorldY = math.abs(worldNormal.Y) > 0.001 and SnapToGrid(draggedWorldFaceCenter.Y, moveStep)
					or draggedWorldFaceCenter.Y
				local snappedWorldZ = math.abs(worldNormal.Z) > 0.001 and SnapToGrid(draggedWorldFaceCenter.Z, moveStep)
					or draggedWorldFaceCenter.Z

				local snappedWorldFaceCenter = Vector3.new(snappedWorldX, snappedWorldY, snappedWorldZ)

				-- 4. Convert the snapped position back into the bounding box's Local Space.
				-- This allows us to figure out the final absolute distance the face moved.
				local snappedLocalFaceCenter = initialBoxCFrame:PointToObjectSpace(snappedWorldFaceCenter)
				targetDistance = (snappedLocalFaceCenter - localFaceOffset):Dot(faceNormal)
			else
				-- RELATIVE SNAPPING: Simply snap the raw mouse distance dragged
				targetDistance = SnapToGrid(distance, moveStep)
			end
		end

		local deltaVector = faceNormal * targetDistance
		local sizeChange = Vector3.new(math.abs(deltaVector.X), math.abs(deltaVector.Y), math.abs(deltaVector.Z))

		if targetDistance < 0 then
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

		local localCenterShift = (actualDeltaSize * faceNormal) / 2
		local worldCenterShift = initialBoxCFrame:VectorToWorldSpace(localCenterShift)

		local newBoxCenter = initialBoxCFrame.Position
		if not isCtrlDown then
			newBoxCenter += worldCenterShift
		end

		local newBoxCFrame = CFrame.new(newBoxCenter) * initialBoxCFrame.Rotation

		proxyPart.Size = newBoxSize
		proxyPart.CFrame = newBoxCFrame

		local boxScaleMultiplier = Vector3.new(
			initialBoxSize.X > minSize and (newBoxSize.X / initialBoxSize.X) or 1,
			initialBoxSize.Y > minSize and (newBoxSize.Y / initialBoxSize.Y) or 1,
			initialBoxSize.Z > minSize and (newBoxSize.Z / initialBoxSize.Z) or 1
		)

		table.clear(partsBatch)
		table.clear(cframesBatch)

		for part, state in pairs(initialStates) do
			local localRelativePos = initialBoxCFrame:PointToObjectSpace(state.CFrame.Position)
			local scaledRelativePos = localRelativePos * boxScaleMultiplier
			local newWorldPos = newBoxCFrame:PointToWorldSpace(scaledRelativePos)
			local targetCFrame = CFrame.new(newWorldPos) * state.CFrame.Rotation

			local localRight = initialBoxCFrame:VectorToObjectSpace(state.CFrame.RightVector)
			local localUp = initialBoxCFrame:VectorToObjectSpace(state.CFrame.UpVector)
			local localLook = initialBoxCFrame:VectorToObjectSpace(state.CFrame.LookVector)

			local localScaleX = (localRight * boxScaleMultiplier).Magnitude
			local localScaleY = (localUp * boxScaleMultiplier).Magnitude
			local localScaleZ = (localLook * boxScaleMultiplier).Magnitude
			local partScaleMultiplier = Vector3.new(localScaleX, localScaleY, localScaleZ)

			part.Size = state.Size * partScaleMultiplier

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
