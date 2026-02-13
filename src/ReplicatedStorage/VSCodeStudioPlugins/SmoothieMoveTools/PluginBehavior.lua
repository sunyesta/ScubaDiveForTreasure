local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Input = require(ReplicatedStorage.Packages.Input)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local GeometricDrag = require(script.Parent.GeometricDrag)
local PluginMouse = require(script.Parent.PluginMouse)
local Vector3Utils = require(script.Parent.Vector3Utils)
local Utils = require(script.Parent.Utils)
local Property = require(script.Parent.PropertyLite)

local Keyboard = Input.Keyboard.new()
local Mouse = PluginMouse.new()

local TransformTypes = {
	Move = "Move",
	Rotate = "Rotate",
	RotateTrackball = "RotateTrackball",
	Twist = "Twist",
	Scale = "Scale",
}

local PluginBehavior = {}
PluginBehavior.__index = PluginBehavior

PluginBehavior.Enum = {}

PluginBehavior.Enum.Axis = {
	Global = "Global", -- World axis
	Local = "Local", -- Object orientation
	View = "View", -- Camera orientation
}

function PluginBehavior.new()
	print("PLUGIN STARTED")

	local self = setmetatable({}, PluginBehavior)
	self._Trove = Trove.new()

	-- Initialize AxisMode to Local by default
	self.Config = {
		Snapping = Property.new(false),
		SnapRotate = Property.new(false),
		AxisMode = Property.new(PluginBehavior.Enum.Axis.Local),
	}

	local activePart = nil
	local selectedParts = {}

	local function UpdateSelection()
		local selected = Selection:Get()

		local addedParts = {}
		selectedParts = TableUtil.Filter(selected, function(inst)
			if inst:IsA("BasePart") then
				return true
			elseif inst:IsA("Model") then
				for _, inst2 in inst:GetDescendants() do
					if inst2 ~= inst.PrimaryPart and inst2:IsA("BasePart") then
						table.insert(addedParts, inst2)
					end
				end
				if inst.PrimaryPart then
					table.insert(addedParts, inst.PrimaryPart)
				end
			end
			return false
		end)
		selectedParts = TableUtil.Extend(selectedParts, addedParts)

		-- update activePart
		if #selectedParts > 0 then
			activePart = selectedParts[#selectedParts]
		else
			activePart = nil
		end
	end

	UpdateSelection()
	Selection.SelectionChanged:Connect(function()
		UpdateSelection()
	end)

	local transformTrove = self._Trove:Extend()

	local transformInfo = nil

	local function RotateDragStyle()
		local function getRotatePlaneNormal()
			local rotatePlaneNormal
			if transformInfo.TransformType:Get() == TransformTypes.Twist then
				rotatePlaneNormal = transformInfo.InitialPivot.UpVector
			elseif transformInfo.DragAxis1 and transformInfo.DragAxis2 then
				rotatePlaneNormal = transformInfo.DragAxis1:Cross(transformInfo.DragAxis2).Unit
			else
				rotatePlaneNormal = transformInfo.DragAxis1
			end
			return rotatePlaneNormal
		end

		return function()
			-- get rotate plane normal
			local rotatePlaneNormal = getRotatePlaneNormal()

			local function getPlaneHit(mouseRay)
				local worldHit = Vector3Utils.LineToPlaneIntersection(
					mouseRay.Origin,
					mouseRay.Direction,
					transformInfo.InitialPivot.Position,
					rotatePlaneNormal
				)

				return worldHit
			end

			local ray = PluginMouse:GetRay()
			local currentPlaneHit = getPlaneHit(ray)
			local initialPlaneHit = getPlaneHit(transformInfo.InitialMouseRay)

			-- Guard against nil intersection if looking parallel to plane
			if not currentPlaneHit or not initialPlaneHit then
				return nil
			end

			local initialVector = (initialPlaneHit - transformInfo.InitialPivot.Position).Unit
			local currentVector = (currentPlaneHit - transformInfo.InitialPivot.Position).Unit

			-- Ensure vectors are not zero before calculating rotation
			if initialVector.Magnitude > 1e-6 and currentVector.Magnitude > 1e-6 then
				local relativeRotation =
					Utils.GetRotationBetweenVectors(initialVector, currentVector, rotatePlaneNormal)
				return CFrame.new(transformInfo.InitialPivot.Position)
					* relativeRotation
					* transformInfo.InitialPivot.Rotation
			end

			return nil
		end
	end

	local function RotateTrackballDragStyle()
		return function()
			local camCFrame = Workspace.CurrentCamera.CFrame

			local rotationSpeed = 0.005

			local screenPosition, visible =
				Workspace.CurrentCamera:WorldToScreenPoint(transformInfo.InitialPivot.Position)
			screenPosition = Vector2.new(screenPosition.X, screenPosition.Y)
			local mouseDelta = (PluginMouse:GetPosition() - screenPosition) - transformInfo.InitialMousePos

			-- Calculate rotation based on mouseDelta
			local rotationX = mouseDelta.Y * rotationSpeed
			local rotationY = 0

			local newCFrame = CFrame.new(transformInfo.InitialPivot.Position)
				* CFrame.fromAxisAngle(camCFrame.LookVector, rotationY)
				* CFrame.fromAxisAngle(camCFrame.RightVector, rotationX)
				* transformInfo.InitialPivot.Rotation

			return newCFrame
		end
	end

	local function TranslateDragStyle()
		local snapRaycastParams = RaycastParams.new()
		snapRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
		snapRaycastParams.FilterDescendantsInstances = selectedParts
		snapRaycastParams.RespectCanCollide = false

		return function(adjustedMousePos)
			local newPos
			local ray = PluginMouse:GetRay(adjustedMousePos)

			if self.Config.Snapping:Get() then
				local result = PluginMouse:Raycast(snapRaycastParams)

				if result then
					if self.Config.SnapRotate:Get() then
						return Utils.YLookAlong(result.Position, result.Normal)
					else
						newPos = result.Position
					end
				else
					newPos = nil
				end
			elseif transformInfo.DragAxis1 and transformInfo.DragAxis2 then
				newPos = Vector3Utils.LineToPlaneIntersection(
					ray.Origin,
					ray.Direction,
					transformInfo.InitialPivot.Position,
					transformInfo.DragAxis1:Cross(transformInfo.DragAxis2)
				)
			elseif transformInfo.DragAxis1 then
				-- moving along one axis
				local planeCFrame = Utils.YLookAlong(activePart:GetPivot().Position, transformInfo.DragAxis1)
				planeCFrame = Utils.LookAtWithoutUp(planeCFrame, ray.Origin)

				newPos = Vector3Utils.LineToPlaneIntersection(
					ray.Origin,
					ray.Direction,
					planeCFrame.Position,
					planeCFrame.LookVector
				)

				if newPos then
					newPos = Vector3Utils.ClosestPointFromPointToLine(
						newPos,
						transformInfo.InitialPivot.Position,
						transformInfo.DragAxis1
					)
				end
			end

			return if newPos then CFrame.new(newPos) * activePart:GetPivot().Rotation else nil
		end
	end

	local function TransformActivePart()
		-- reset transformInfo
		transformInfo = {}
		transformTrove:Add(function()
			task.spawn(function()
				task.wait()
				transformInfo = nil
			end)
		end)

		transformInfo.ActivePart = activePart
		transformInfo.SnappingTrove = transformTrove:Extend()

		-- Initial Setup: Default to View Plane dragging (screen space)
		local planeCFrame =
			Utils.LookAtWithoutUp(CFrame.new(activePart:GetPivot().Position), Workspace.CurrentCamera.CFrame.Position)
		transformInfo.ViewPlane = planeCFrame

		-- Default constraint: Move on the view plane
		transformInfo.DragAxis1, transformInfo.DragAxis2 = planeCFrame.RightVector, planeCFrame.UpVector

		transformInfo.InitialPivot = activePart:GetPivot()
		transformInfo.InitialMouseRay = PluginMouse:GetRay()
		transformInfo.InitialMousePos = PluginMouse:GetPosition()

		-- add undo steps
		ChangeHistoryService:SetWaypoint("Moved")
		transformTrove:Add(function()
			ChangeHistoryService:SetWaypoint("Moved")
		end)

		-- set camera
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		transformTrove:Add(function()
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
		end)

		-- create new transformInfo.Drag
		local drag = GeometricDrag.new(activePart)
		PluginMouse:Enable()

		transformInfo.TransformType = Property.new(TransformTypes.Move)

		transformTrove:Add(transformInfo.TransformType:Observe(function(transformType)
			if transformType == TransformTypes.Move then
				drag:SetDragStyle(TranslateDragStyle())
			elseif transformType == TransformTypes.Rotate or transformType == TransformTypes.Twist then
				drag:SetDragStyle(RotateDragStyle())
			elseif transformType == TransformTypes.RotateTrackball then
				drag:SetDragStyle(RotateTrackballDragStyle())
			end
		end))

		local curSelectedParts = selectedParts
		-- move all selected parts with active part
		local partOffsets = TableUtil.Map(curSelectedParts, function(part)
			return activePart:GetPivot():ToObjectSpace(part:GetPivot())
		end)
		local function updateAllPartPositions()
			for i, part in curSelectedParts do
				part:PivotTo(activePart:GetPivot():ToWorldSpace(partOffsets[i]))
			end
		end

		drag:StartDrag()
		transformTrove:Add(function()
			drag:StopDrag()
			drag:Destroy()
			updateAllPartPositions()
		end)

		RunService:BindToRenderStep("UpdateMove", 3, function()
			updateAllPartPositions()
		end)

		transformTrove:Add(function()
			RunService:UnbindFromRenderStep("UpdateMove")
		end)

		-- stop dragging on undo
		transformTrove:Add(ChangeHistoryService.OnUndo:Connect(function()
			transformTrove:Clean()
		end))
		transformTrove:Add(ChangeHistoryService.OnRedo:Connect(function()
			transformTrove:Clean()
		end))

		-- clean the transformTrove when right mouse button is down
		transformTrove:Add(Mouse.RightDown:Connect(function()
			transformTrove:Clean()
		end))

		transformTrove:Add(Mouse.LeftDown:Connect(function()
			transformTrove:Clean()
		end))

		transformTrove:Add(Selection.SelectionChanged:Connect(function()
			if transformInfo then
				-- Reset to initial pivot if selection changes during transform
				if transformInfo.InitialPivot and activePart then
					activePart:PivotTo(transformInfo.InitialPivot)
				end
			end
			transformTrove:Clean()
		end))
	end

	local function duplicateSelected()
		local selection = Utils.ToDict(Selection:Get())

		for _, inst in pairs(Selection:Get()) do
			-- get inst to clone
			-- if the inst's ancestor is selected too, skip the inst
			local selectedAncestor = Utils.FindAncestor(inst, function(ancestor)
				return selection[ancestor]
			end, false)
			if selectedAncestor then
				continue
			end

			local instClone = inst:Clone()
			instClone.Parent = inst.Parent
		end

		TransformActivePart()
	end

	local hiddenTrove = self._Trove:Extend()
	local function hideSelected(toggle)
		if toggle then
			for _, part in selectedParts do
				local oldParent = part.Parent
				part.Parent = nil

				hiddenTrove:Add(function()
					part.Parent = oldParent
				end)
			end

			ChangeHistoryService:SetWaypoint("Hide Parts")
		else
			hiddenTrove:Clean()
			ChangeHistoryService:SetWaypoint("Unhide Parts")
		end
	end

	self._Trove:Add(Keyboard.KeyDown:Connect(function(key)
		-- hotkeys
		if transformInfo and key == Enum.KeyCode.LeftControl then
			self.Config.Snapping:Set(not self.Config.Snapping:Get())
			transformInfo.SnappingTrove:Add(function()
				self.Config.Snapping:Set(not self.Config.Snapping:Get())
			end)
		elseif key == Enum.KeyCode.D and Keyboard:IsKeyDown(Enum.KeyCode.LeftControl) then
			duplicateSelected()
		elseif key == Enum.KeyCode.Escape then
			if transformInfo then
				transformTrove:Clean()
			else
				Selection:Set({})
			end
		elseif key == Enum.KeyCode.A and Keyboard:IsKeyDown(Enum.KeyCode.LeftAlt) then
			Selection:Set({})
		elseif key == Enum.KeyCode.H then
			if Keyboard:IsKeyDown(Enum.KeyCode.LeftAlt) then
				hideSelected(false)
			else
				hideSelected(true)
			end

		-- Cycle Axis Mode
		elseif key == Enum.KeyCode.L then
			local currentMode = self.Config.AxisMode:Get()
			if currentMode == PluginBehavior.Enum.Axis.Global then
				self.Config.AxisMode:Set(PluginBehavior.Enum.Axis.Local)
				print("Axis Mode: Local")
			elseif currentMode == PluginBehavior.Enum.Axis.Local then
				self.Config.AxisMode:Set(PluginBehavior.Enum.Axis.View)
				print("Axis Mode: View")
			else
				self.Config.AxisMode:Set(PluginBehavior.Enum.Axis.Global)
				print("Axis Mode: Global")
			end
		end

		-- dragTools
		if activePart then
			if key == Enum.KeyCode.G or key == Enum.KeyCode.R or key == Enum.KeyCode.T then
				if not transformInfo then
					TransformActivePart()
				end
			end
		end

		if transformInfo then
			if key == Enum.KeyCode.G then
				transformInfo.TransformType:Set(TransformTypes.Move)
			elseif key == Enum.KeyCode.R then
				if transformInfo.TransformType == TransformTypes.Rotate then
					transformInfo.TransformType:Set(TransformTypes.RotateTrackball)
				else
					transformInfo.TransformType:Set(TransformTypes.Rotate)
				end
			elseif key == Enum.KeyCode.T then
				transformInfo.TransformType:Set(TransformTypes.Twist)
			end

			-- Reset to initial pivot before applying new axis constraint
			if key == Enum.KeyCode.X or key == Enum.KeyCode.Y or key == Enum.KeyCode.Z then
				activePart:PivotTo(transformInfo.InitialPivot)
			end

			-- Determine Base Axes based on Mode
			local mode = self.Config.AxisMode:Get()
			local xAxis, yAxis, zAxis

			if mode == PluginBehavior.Enum.Axis.Global then
				xAxis = Vector3.xAxis
				yAxis = Vector3.zAxis -- Swapped Y and Z vectors
				zAxis = Vector3.yAxis
			elseif mode == PluginBehavior.Enum.Axis.Local then
				-- Use initial pivot rotation
				local pivot = transformInfo.InitialPivot
				xAxis = pivot.RightVector
				yAxis = -pivot.LookVector -- Swapped (was UpVector)
				zAxis = pivot.UpVector -- Swapped (was -LookVector)
			elseif mode == PluginBehavior.Enum.Axis.View then
				local viewPlane = transformInfo.ViewPlane
				xAxis = viewPlane.RightVector
				yAxis = viewPlane.LookVector -- Swapped
				zAxis = viewPlane.UpVector -- Swapped
			end

			-- Apply Constraints
			if Keyboard:IsKeyDown(Enum.KeyCode.LeftShift) then
				-- Plane Constraints (e.g. Shift+X = Lock to YZ plane)
				if key == Enum.KeyCode.X then
					transformInfo.DragAxis1, transformInfo.DragAxis2 = yAxis, zAxis
				elseif key == Enum.KeyCode.Y then
					transformInfo.DragAxis1, transformInfo.DragAxis2 = xAxis, zAxis
				elseif key == Enum.KeyCode.Z then
					transformInfo.DragAxis1, transformInfo.DragAxis2 = xAxis, yAxis
				end
			else
				-- Axis Constraints (e.g. X = Lock to X axis)
				if key == Enum.KeyCode.X then
					transformInfo.DragAxis1, transformInfo.DragAxis2 = xAxis, nil
				elseif key == Enum.KeyCode.Y then
					transformInfo.DragAxis1, transformInfo.DragAxis2 = yAxis, nil
				elseif key == Enum.KeyCode.Z then
					transformInfo.DragAxis1, transformInfo.DragAxis2 = zAxis, nil
				end
			end
		else
			-- Delete functionality
			if key == Enum.KeyCode.X then
				-- Safety check: only delete if not holding shift/modifiers if desired,
				-- but sticking to original logic here:
				if #Selection:Get() > 0 then
					for _, inst in (Selection:Get()) do
						inst.Parent = nil
					end
					ChangeHistoryService:SetWaypoint("Destroyed")
				end
			end
		end
	end))

	self._Trove:Add(Keyboard.KeyUp:Connect(function(key)
		-- extra modifiers
		if transformInfo and key == Enum.KeyCode.LeftControl then
			transformInfo.SnappingTrove:Clean()
		end
	end))

	local lastTopSelection = nil
	local selectionIndex = -1
	self._Trove:Add(PluginMouse.LeftDown:Connect(function()
		if transformInfo then
			return
		end
		local function findFirstValidPart()
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude

			local firstPos

			local candidates = {}
			while true do
				local result = PluginMouse:Raycast(raycastParams)

				if result then
					firstPos = firstPos or result.Position

					if (result.Position - firstPos).Magnitude < 2 then
						if result.Instance.Locked == false then
							table.insert(candidates, result.Instance)
						end

						raycastParams:AddToFilter(result.Instance)
					else
						break
					end
				else
					break
				end
			end

			if #candidates == 0 then
				lastTopSelection = nil
				return nil
			end

			if candidates[1] == lastTopSelection then
				selectionIndex += 1
				return candidates[(selectionIndex % #candidates) + 1]
			else
				selectionIndex = 0
				lastTopSelection = candidates[1]
				return candidates[1]
			end
		end

		local inst = findFirstValidPart()

		if inst then
			if not Keyboard:IsKeyDown(Enum.KeyCode.LeftAlt) then
				local model = inst:FindFirstAncestorWhichIsA("Model")
				if model and model ~= workspace then
					inst = model
				end
			end
		end

		if Keyboard:IsKeyDown(Enum.KeyCode.LeftShift) then
			if inst then
				local alreadySelected = if table.find(selectedParts, inst) then true else false
				if alreadySelected then
					Selection:Remove({ inst })
				else
					Selection:Add({ inst })
				end
			end
		else
			Selection:Set({ inst })
		end

		ChangeHistoryService:SetWaypoint("Selected")
	end))

	-- place origin at pivot of activePart
	local SmoothieGuiFolder = self._Trove:Add(
		if script.Parent:FindFirstChild("SmoothieGuiPluginGuiFolder")
			then script.Parent.SmoothieGuiPluginGuiFolder:Clone()
			else ReplicatedStorage.TemporaryStudioPlugins.SmoothieMoveTools.SmoothieGuiPluginGuiFolder:Clone()
	)
	SmoothieGuiFolder.Parent = CoreGui
	local OriginLabel = SmoothieGuiFolder.OriginGui.Origin

	-- Update GUI to show Axis Mode if desired, or just print for now as implemented in KeyDown
	RunService:BindToRenderStep("UpdateOriginLabel", 1, function()
		OriginLabel.Visible = true
		if activePart then
			local position = activePart:GetPivot().Position
			local screenPosition, visible = Workspace.CurrentCamera:WorldToScreenPoint(position)

			if visible then
				OriginLabel.Position = UDim2.new(0, screenPosition.X, 0, screenPosition.Y)
			else
				OriginLabel.Visible = false
			end
		else
			OriginLabel.Visible = false
		end
	end)

	self._Trove:Add(function()
		RunService:UnbindFromRenderStep("UpdateOriginLabel")
	end)

	return self
end

function PluginBehavior:Destroy()
	print("DESTROYING")
	self._Trove:Clean()
end

function PluginBehavior:UpdateSurfaceAppearances()
	for _, selected in Selection:Get() do
		if selected:IsA("SurfaceAppearance") then
			for _, inst in workspace:GetDescendants() do
				if inst ~= selected and inst:IsA("SurfaceAppearance") and inst.Name == selected.Name then
					local parent = inst.Parent
					inst.Parent = nil
					local newSA = selected:Clone()
					newSA.Parent = parent
				end
			end
		end
	end
	ChangeHistoryService:SetWaypoint("UpdatedSAs")
end

function PluginBehavior:CopySAToSelected()
	local surfAppearance = TableUtil.Find(Selection:Get(), function(inst)
		return inst:IsA("SurfaceAppearance")
	end)

	assert(surfAppearance, "No surface appearance found")

	for _, inst in Selection:Get() do
		local parent
		if inst:IsA("BasePart") then
			parent = inst
		elseif inst:IsA("Model") and inst.PrimaryPart then
			parent = inst.PrimaryPart
		end

		if parent then
			local oldSA = parent:FindFirstChildWhichIsA("SurfaceAppearance")
			if oldSA then
				oldSA.Parent = nil
			end

			local newSA = surfAppearance:Clone()
			newSA.Parent = parent
		end
	end

	ChangeHistoryService:SetWaypoint("CopiedSAs")
end

return PluginBehavior
