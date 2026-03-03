--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Props = require(script.Parent.Props)
local Enums = require(script.Parent.Enums)
local GeometricDrag = require(script.Parent.Modules.GeometricDrag)
local PluginMouse = require(script.Parent.Modules.PluginMouse)
local SelectionBehavior = require(script.Parent.SelectionBehavior)

-- Configuration
local TRACKBALL_SENSITIVITY = 5

local MoveAndRotateBehavior = {}

type SaveStateFunc = (ray: Ray?, pos: Vector2?) -> ()

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

local function SnapToGrid(value: number, step: number): number
	if step <= 0 then
		return value
	end
	return math.round(value / step) * step
end

local function LineToPlaneIntersection(
	origin: Vector3,
	direction: Vector3,
	planeOrigin: Vector3,
	planeNormal: Vector3
): Vector3?
	local diff = origin - planeOrigin
	local prod1 = diff:Dot(planeNormal)
	local prod2 = direction:Dot(planeNormal)

	if math.abs(prod2) < 1e-6 then
		return nil
	end

	local prod3 = prod1 / prod2
	return origin - (direction * prod3)
end

local function ClosestPointFromPointToLine(point: Vector3, lineOrigin: Vector3, lineDirection: Vector3): Vector3
	local direction = lineDirection.Unit
	local v = point - lineOrigin
	local projection = v:Dot(direction)
	return lineOrigin + direction * projection
end

local function GetSignedAngleBetweenVectors(vectorA: Vector3, vectorB: Vector3, planeNormal: Vector3): number
	local normalizedA = vectorA.Unit
	local normalizedB = vectorB.Unit
	local dotProduct = math.clamp(normalizedA:Dot(normalizedB), -1, 1)
	local angle = math.acos(dotProduct)

	local crossProductAB = vectorA:Cross(vectorB)

	if crossProductAB:Dot(planeNormal) < 0 then
		angle = -angle
	end

	return angle
end

local function YLookAlong(at: Vector3, direction: Vector3, xDirection: Vector3?): CFrame
	return CFrame.lookAlong(at, direction) * CFrame.fromEulerAnglesXYZ(math.rad(-90), 0, 0)
end

local function LookAtWithoutUp(currentCFrame: CFrame, targetPoint: Vector3): CFrame
	local currentPosition = currentCFrame.Position
	local upVector = currentCFrame.UpVector
	local directionToTarget = (targetPoint - currentPosition)
	local directionOnPlane = directionToTarget - (directionToTarget:Dot(upVector) * upVector)

	if directionOnPlane.Magnitude < 1e-5 then
		return currentCFrame
	end

	local newLookVector = directionOnPlane.Unit
	local newRightVector = upVector:Cross(newLookVector).Unit

	return CFrame.fromMatrix(currentPosition, newRightVector, upVector, newLookVector)
end

local function GetWorkingAxes(originCFrame: CFrame): (Vector3, Vector3, Vector3)
	local axisMode = Props.Axis:Get()

	if axisMode == Enums.Axis.Global then
		return Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	elseif axisMode == Enums.Axis.View then
		local camCFrame = Workspace.CurrentCamera.CFrame
		return camCFrame.RightVector, camCFrame.UpVector, -camCFrame.LookVector
	else
		return originCFrame.RightVector, originCFrame.UpVector, -originCFrame.LookVector
	end
end

--------------------------------------------------------------------------------
-- DRAG STYLES
--------------------------------------------------------------------------------

local function TranslateDragStyle(
	initialOrigin: CFrame,
	dragAxis1: Vector3,
	dragAxis2: Vector3?,
	initialMouseRay: Ray?,
	saveState: SaveStateFunc?
)
	local selectedParts = Props.SelectedParts:Get()

	local snapRaycastParams = RaycastParams.new()
	snapRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	snapRaycastParams.FilterDescendantsInstances = selectedParts
	snapRaycastParams.RespectCanCollide = false

	local function calculateHit(ray: Ray)
		local hitPos = nil

		if dragAxis1 and dragAxis2 then
			hitPos =
				LineToPlaneIntersection(ray.Origin, ray.Direction, initialOrigin.Position, dragAxis1:Cross(dragAxis2))
		elseif dragAxis1 then
			local planeCFrame = YLookAlong(initialOrigin.Position, dragAxis1)
			planeCFrame = LookAtWithoutUp(planeCFrame, ray.Origin)
			hitPos = LineToPlaneIntersection(ray.Origin, ray.Direction, planeCFrame.Position, planeCFrame.LookVector)

			if hitPos then
				hitPos = ClosestPointFromPointToLine(hitPos, initialOrigin.Position, dragAxis1)
			end
		end

		return hitPos
	end

	local initialHit: Vector3? = nil
	if initialMouseRay then
		initialHit = calculateHit(initialMouseRay)
	end

	return function(_adjustedMousePos: Vector2)
		local useSnapping = Props.UseSnapping:Get()
		local snappingMode = Props.SnappingMode:Get()
		local currentRay = PluginMouse:GetRay()

		if useSnapping and snappingMode == Enums.SnappingMode.Surface then
			local result = Workspace:Raycast(currentRay.Origin, currentRay.Direction * 1000, snapRaycastParams)

			if result then
				if Props.MatchRotationToSurface:Get() then
					return YLookAlong(result.Position, result.Normal)
				else
					return CFrame.new(result.Position) * initialOrigin.Rotation
				end
			end

			return nil
		end

		-- Capture state dynamically on the first frame if it wasn't passed via a hot-swap
		if not initialHit then
			initialHit = calculateHit(currentRay)
			if saveState then
				saveState(currentRay, nil)
			end
		end

		local currentHit = calculateHit(currentRay)

		if not currentHit or not initialHit then
			return nil
		end

		local delta = currentHit - initialHit
		local moveStep = Props.MoveStudsIncrement:Get()

		if useSnapping and snappingMode == Enums.SnappingMode.Grid then
			moveStep = Props.GridSize:Get()
		end

		if moveStep > 0 then
			if dragAxis1 and dragAxis2 then
				local rightDot = SnapToGrid(delta:Dot(dragAxis1), moveStep)
				local upDot = SnapToGrid(delta:Dot(dragAxis2), moveStep)
				delta = (dragAxis1 * rightDot) + (dragAxis2 * upDot)
			elseif dragAxis1 then
				local dot = SnapToGrid(delta:Dot(dragAxis1), moveStep)
				delta = dragAxis1 * dot
			end
		end

		return CFrame.new(initialOrigin.Position + delta) * initialOrigin.Rotation
	end
end

local function RotateDragStyle(
	initialOrigin: CFrame,
	dragAxis1: Vector3,
	dragAxis2: Vector3?,
	initialMouseRay: Ray?,
	saveState: SaveStateFunc?
)
	local function getRotatePlaneNormal()
		if dragAxis1 and dragAxis2 then
			return dragAxis1:Cross(dragAxis2).Unit
		else
			return dragAxis1
		end
	end

	local rotatePlaneNormal = getRotatePlaneNormal()

	local function getPlaneHit(mouseRay: Ray)
		return LineToPlaneIntersection(mouseRay.Origin, mouseRay.Direction, initialOrigin.Position, rotatePlaneNormal)
	end

	local initialPlaneHit: Vector3? = nil
	if initialMouseRay then
		initialPlaneHit = getPlaneHit(initialMouseRay)
	end

	return function(_adjustedMousePos: Vector2)
		local currentRay = PluginMouse:GetRay()

		-- Capture state dynamically on the first frame if it wasn't passed via a hot-swap
		if not initialPlaneHit then
			initialPlaneHit = getPlaneHit(currentRay)
			if saveState then
				saveState(currentRay, nil)
			end
		end

		local currentPlaneHit = getPlaneHit(currentRay)

		if not currentPlaneHit or not initialPlaneHit then
			return nil
		end

		local initialVector = (initialPlaneHit - initialOrigin.Position).Unit
		local currentVector = (currentPlaneHit - initialOrigin.Position).Unit

		if initialVector.Magnitude > 1e-6 and currentVector.Magnitude > 1e-6 then
			local angle = GetSignedAngleBetweenVectors(initialVector, currentVector, rotatePlaneNormal)
			local rotStep = Props.RotationDegIncrement:Get()

			if rotStep > 0 then
				angle = SnapToGrid(angle, math.rad(rotStep))
			end

			return CFrame.new(initialOrigin.Position)
				* CFrame.fromAxisAngle(rotatePlaneNormal, angle)
				* initialOrigin.Rotation
		end

		return nil
	end
end

local function TrackballDragStyle(initialOrigin: CFrame, initialMousePos: Vector2?, saveState: SaveStateFunc?)
	local cam = Workspace.CurrentCamera
	local centerPos, onScreen = cam:WorldToViewportPoint(initialOrigin.Position)
	local center2D = Vector2.new(centerPos.X, centerPos.Y)

	local viewportSize = cam.ViewportSize
	local trackballRadius = math.max(1, math.min(viewportSize.X, viewportSize.Y) / 2)

	if not onScreen then
		center2D = viewportSize / 2
	end

	local function projectToSphere(pos2D: Vector2): Vector3
		local x = (pos2D.X - center2D.X) / trackballRadius
		local y = -(pos2D.Y - center2D.Y) / trackballRadius

		local r2 = x * x + y * y
		if r2 <= 1 then
			return Vector3.new(x, y, math.sqrt(1 - r2))
		else
			local length = math.sqrt(r2)
			return Vector3.new(x / length, y / length, 0)
		end
	end

	local vStart: Vector3? = nil
	if initialMousePos then
		vStart = projectToSphere(initialMousePos)
	end

	return function(_adjustedMousePos: Vector2)
		local currentMousePos = PluginMouse:GetPosition()

		if not vStart then
			vStart = projectToSphere(currentMousePos)
			if saveState then
				saveState(nil, currentMousePos)
			end
		end

		local startVec = vStart :: Vector3
		local vCurrent = projectToSphere(currentMousePos)

		local dot = math.clamp(startVec:Dot(vCurrent), -1, 1)
		local angle = math.acos(dot) * TRACKBALL_SENSITIVITY

		if angle < 1e-5 then
			return initialOrigin
		end

		local axisCamSpace = startVec:Cross(vCurrent)
		if axisCamSpace.Magnitude < 1e-5 then
			return initialOrigin
		end
		axisCamSpace = axisCamSpace.Unit

		local axisWorld = cam.CFrame:VectorToWorldSpace(axisCamSpace)
		local rotationDelta = CFrame.fromAxisAngle(axisWorld, angle)

		return CFrame.new(initialOrigin.Position) * rotationDelta * initialOrigin.Rotation
	end
end

--------------------------------------------------------------------------------
-- INITIALIZATION & LIFECYCLE
--------------------------------------------------------------------------------

function MoveAndRotateBehavior.Init(plugin: Plugin, pluginTrove: any)
	local Keyboard = require(script.Parent.Modules.Keyboard).new()
	local Mouse = PluginMouse.new()

	type DragSession = {
		Type: string,
		InitialOrigin: CFrame,
		OriginalCFrames: { [BasePart]: CFrame },
		OriginalPivotOffsets: { [BasePart]: CFrame },
		PartOffsets: { [BasePart]: CFrame },
		PreviousRibbonTool: Enum.RibbonTool?,
		InitialSelection: { Instance },
		InitialMouseRay: Ray?,
		InitialMousePos: Vector2?,
		Drag: any, -- Represents the GeometricDrag object
		DragStyleFunc: (Vector2) -> CFrame?,
		UpdateConnection: RBXScriptConnection?,
		Cleanup: () -> (),
	}

	local currentSession: DragSession? = nil

	local function StopSession(commit: boolean)
		if currentSession then
			SelectionBehavior.IsTransforming = false
			Props.HideGizmos:Set(false)

			local previousTool = currentSession.PreviousRibbonTool
			local initialSelection = currentSession.InitialSelection
			currentSession.Cleanup()

			if not commit then
				for part, cframe in pairs(currentSession.OriginalCFrames) do
					-- Safely restore the original pivot offset and part CFrame
					if currentSession.OriginalPivotOffsets[part] then
						part.PivotOffset = currentSession.OriginalPivotOffsets[part]
					end
					part:PivotTo(cframe)
				end
			else
				ChangeHistoryService:SetWaypoint(currentSession.Type .. " Transformed")
			end

			currentSession = nil
			Props.TransformOrigin:Set(SelectionBehavior.CalculateTransformOrigin())

			task.spawn(function()
				while
					UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
					or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				do
					task.wait()
				end

				if currentSession then
					return
				end

				plugin:Deactivate()

				if previousTool then
					pcall(function()
						plugin:SelectRibbonTool(previousTool)
					end)
				end

				task.defer(function()
					Selection:Set(initialSelection)
				end)
			end)
		end
	end

	local function StartSession(transformType: string, dragAxis1: Vector3, dragAxis2: Vector3?)
		-- HOT-SWAP LOGIC: If a session exists, safely change the transform constraints mid-drag
		if currentSession then
			currentSession.Type = transformType

			local dragStyleFunc
			if transformType == Enums.TransformType.Move then
				dragStyleFunc = TranslateDragStyle(
					currentSession.InitialOrigin,
					dragAxis1,
					dragAxis2,
					currentSession.InitialMouseRay,
					nil
				)
			elseif transformType == Enums.TransformType.Rotate then
				dragStyleFunc = RotateDragStyle(
					currentSession.InitialOrigin,
					dragAxis1,
					dragAxis2,
					currentSession.InitialMouseRay,
					nil
				)
			elseif transformType == Enums.TransformType.RotateTrackball then
				dragStyleFunc = TrackballDragStyle(currentSession.InitialOrigin, currentSession.InitialMousePos, nil)
			elseif transformType == Enums.TransformType.Twist then
				dragStyleFunc = RotateDragStyle(
					currentSession.InitialOrigin,
					currentSession.InitialOrigin.UpVector,
					nil,
					currentSession.InitialMouseRay,
					nil
				)
			end

			if dragStyleFunc then
				currentSession.DragStyleFunc = dragStyleFunc
				currentSession.Drag:SetDragStyle(function(adjustedMousePos)
					return currentSession.DragStyleFunc(adjustedMousePos)
				end)

				-- Step the drag forcefully so the part visualizes on the new axis immediately
				local mousePos = PluginMouse:GetPosition()
				local newTransformOrigin = currentSession.Drag:Step(mousePos)
				if newTransformOrigin then
					local originsOnly = Props.OriginsOnly:Get()

					for part, offset in pairs(currentSession.PartOffsets) do
						local targetPivot = newTransformOrigin:ToWorldSpace(offset)

						if originsOnly then
							-- Only modify PivotOffset, leave geometry unchanged
							part.PivotOffset = part.CFrame:ToObjectSpace(targetPivot)
						else
							-- Move whole part (restore original PivotOffset to avoid mid-toggle jumps)
							part.PivotOffset = currentSession.OriginalPivotOffsets[part]
							part:PivotTo(targetPivot)
						end
					end
					Props.TransformOrigin:Set(newTransformOrigin)
				end
			end

			return -- Exit function so we don't start a new session!
		end

		-- NEW SESSION LOGIC: Setup the initial states
		local previousTool = plugin:GetSelectedRibbonTool()
		local currentSelection = Selection:Get()

		plugin:Activate(true)

		local selectedParts = Props.SelectedParts:Get()
		if #selectedParts == 0 then
			return
		end

		local activePart = Props.ActivePart:Get() or selectedParts[1]
		local initialOrigin = SelectionBehavior.CalculateTransformOrigin()

		Props.TransformOrigin:Set(initialOrigin)
		Props.HideGizmos:Set(true)

		SelectionBehavior.IsTransforming = true

		local originalCFrames = {}
		local originalPivotOffsets = {}
		local partOffsets = {}

		for _, part in ipairs(selectedParts) do
			if part:IsA("BasePart") then
				local pivot = part:GetPivot()
				originalCFrames[part] = pivot
				originalPivotOffsets[part] = part.PivotOffset
				partOffsets[part] = initialOrigin:ToObjectSpace(pivot)
			end
		end

		local function saveInitialState(ray: Ray?, pos: Vector2?)
			if currentSession then
				if ray then
					currentSession.InitialMouseRay = ray
				end
				if pos then
					currentSession.InitialMousePos = pos
				end
			end
		end

		local dragStyleFunc
		if transformType == Enums.TransformType.Move then
			dragStyleFunc = TranslateDragStyle(initialOrigin, dragAxis1, dragAxis2, nil, saveInitialState)
		elseif transformType == Enums.TransformType.Rotate then
			dragStyleFunc = RotateDragStyle(initialOrigin, dragAxis1, dragAxis2, nil, saveInitialState)
		elseif transformType == Enums.TransformType.RotateTrackball then
			dragStyleFunc = TrackballDragStyle(initialOrigin, nil, saveInitialState)
		elseif transformType == Enums.TransformType.Twist then
			dragStyleFunc = RotateDragStyle(initialOrigin, initialOrigin.UpVector, nil, nil, saveInitialState)
		end

		if not dragStyleFunc then
			return
		end

		local drag = GeometricDrag.new(activePart)

		if typeof(PluginMouse.Enable) == "function" then
			PluginMouse:Enable()
		end

		-- Prepare currentSession before assigning SetDragStyle, ensuring our save callback functions seamlessly
		currentSession = {
			Type = transformType,
			InitialOrigin = initialOrigin,
			OriginalCFrames = originalCFrames,
			OriginalPivotOffsets = originalPivotOffsets,
			PartOffsets = partOffsets,
			PreviousRibbonTool = previousTool,
			InitialSelection = currentSelection,
			InitialMouseRay = nil,
			InitialMousePos = nil,
			Drag = drag,
			DragStyleFunc = dragStyleFunc,
			UpdateConnection = nil,
			Cleanup = function()
				if currentSession and currentSession.UpdateConnection then
					currentSession.UpdateConnection:Disconnect()
				end
				drag:StopDrag()
				drag:Destroy()
			end,
		}

		drag:SetDragStyle(function(adjustedMousePos)
			return currentSession.DragStyleFunc(adjustedMousePos)
		end)

		drag:StartDrag()

		currentSession.UpdateConnection = RunService.Heartbeat:Connect(function()
			local mousePos = PluginMouse:GetPosition()
			local newTransformOrigin = drag:Step(mousePos)

			if newTransformOrigin then
				local originsOnly = Props.OriginsOnly:Get()

				for part, offset in pairs(partOffsets) do
					local targetPivot = newTransformOrigin:ToWorldSpace(offset)

					if originsOnly then
						-- Math explanation: part.CFrame * part.PivotOffset = targetPivot
						-- Therefore: part.PivotOffset = part.CFrame:Inverse() * targetPivot
						part.PivotOffset = part.CFrame:ToObjectSpace(targetPivot)
					else
						-- Reset pivot to original just in case they toggled OriginsOnly mid-drag
						part.PivotOffset = originalPivotOffsets[part]
						part:PivotTo(targetPivot)
					end
				end

				Props.TransformOrigin:Set(newTransformOrigin)
			end
		end)
	end

	MoveAndRotateBehavior.StartTransformation = StartSession
	MoveAndRotateBehavior.StopTransformation = StopSession

	pluginTrove:Add(Keyboard.KeyDown:Connect(function(inputKey)
		local key = inputKey

		if Props.SwapYandZKeybinds:Get() then
			if inputKey == Enum.KeyCode.Y then
				key = Enum.KeyCode.Z
			elseif inputKey == Enum.KeyCode.Z then
				key = Enum.KeyCode.Y
			end
		end

		local activePart = Props.ActivePart:Get()

		if activePart and not currentSession then
			if key == Enum.KeyCode.G then
				local cam = Workspace.CurrentCamera.CFrame
				StartSession(Enums.TransformType.Move, cam.RightVector, cam.UpVector)
			elseif key == Enum.KeyCode.R then
				local camLookVector = Workspace.CurrentCamera.CFrame.LookVector
				StartSession(Enums.TransformType.Rotate, camLookVector)
			elseif key == Enum.KeyCode.T then
				StartSession(Enums.TransformType.Twist, Vector3.yAxis)
			end
		elseif currentSession then
			local xAxis, yAxis, zAxis = GetWorkingAxes(currentSession.InitialOrigin)
			local shiftDown = Keyboard:IsKeyDown(Enum.KeyCode.LeftShift)

			if key == Enum.KeyCode.G then
				local cam = Workspace.CurrentCamera.CFrame
				StartSession(Enums.TransformType.Move, cam.RightVector, cam.UpVector)
			elseif key == Enum.KeyCode.R then
				if currentSession.Type == Enums.TransformType.Rotate then
					StartSession(Enums.TransformType.RotateTrackball, Vector3.zero, nil)
				elseif currentSession.Type == Enums.TransformType.RotateTrackball then
					local camLookVector = Workspace.CurrentCamera.CFrame.LookVector
					StartSession(Enums.TransformType.Rotate, camLookVector)
				else
					local camLookVector = Workspace.CurrentCamera.CFrame.LookVector
					StartSession(Enums.TransformType.Rotate, camLookVector)
				end
			elseif key == Enum.KeyCode.T then
				StartSession(Enums.TransformType.Twist, Vector3.yAxis)
			elseif key == Enum.KeyCode.X then
				if shiftDown then
					StartSession(currentSession.Type, yAxis, zAxis)
				else
					StartSession(currentSession.Type, xAxis, nil)
				end
			elseif key == Enum.KeyCode.Y then
				if shiftDown then
					StartSession(currentSession.Type, xAxis, zAxis)
				else
					StartSession(currentSession.Type, yAxis, nil)
				end
			elseif key == Enum.KeyCode.Z then
				if shiftDown then
					StartSession(currentSession.Type, xAxis, yAxis)
				else
					StartSession(currentSession.Type, zAxis, nil)
				end
			elseif key == Enum.KeyCode.Escape then
				StopSession(false)
			end
		end
	end))

	pluginTrove:Add(Mouse.LeftDown:Connect(function()
		if currentSession then
			StopSession(true)
		end
	end))

	pluginTrove:Add(Mouse.RightDown:Connect(function()
		if currentSession then
			StopSession(false)
		end
	end))

	pluginTrove:Add(Selection.SelectionChanged:Connect(function()
		if currentSession then
			StopSession(false)
		end
	end))

	pluginTrove:Add(plugin.Deactivation:Connect(function()
		if currentSession then
			StopSession(false)
		end
	end))
end

return MoveAndRotateBehavior
