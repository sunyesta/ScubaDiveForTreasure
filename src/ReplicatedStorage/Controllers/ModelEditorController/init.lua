local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Input = require(ReplicatedStorage.Packages.Input)
local GameEnums = require(ReplicatedStorage.Common.GameInfo.GameEnums)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Assert = require(ReplicatedStorage.NonWallyPackages.Assert)
local ClickDetector = require(ReplicatedStorage.NonWallyPackages.ClickDetector)
local InstanceUtils = require(ReplicatedStorage.NonWallyPackages.InstanceUtils)
local WeldUtils = require(ReplicatedStorage.NonWallyPackages.WeldUtils)
local Pass = require(ReplicatedStorage.NonWallyPackages.Pass)
local DefaultValue = require(ReplicatedStorage.NonWallyPackages.DefaultValue)
local RequiredValue = require(ReplicatedStorage.NonWallyPackages.RequiredValue)
local RaycastUtils = require(ReplicatedStorage.NonWallyPackages.RaycastUtils)
local GeometricDrag = require(ReplicatedStorage.NonWallyPackages.GeometricDrag)
local Vector3Utils = require(ReplicatedStorage.NonWallyPackages.Vector3Utils)
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)
local ModelUtils = require(ReplicatedStorage.NonWallyPackages.ModelUtils)
local SimpleFuncs = require(ReplicatedStorage.NonWallyPackages.SimpleFuncs)
local MouseTouch = require(ReplicatedStorage.NonWallyPackages.MouseTouch)
local ModelEditorUtils = require(script.ModelEditorUtils)
local MouseIcons = require(script.MouseIcons)
local ModelEditorConfigs = require(script.ModelEditorConfigs)
local CustomMaterial = require(ReplicatedStorage.Common.Modules.CustomMaterial)
local Props = require(script.Props)
local Enums = require(script.Enums)
local MoveTool = require(script.Tools.MoveTool)
local PaintTool = require(script.Tools.PaintTool)
local RotateTool = require(script.Tools.RotateTool)
local HistoryManager = require(script.HistoryManager)

local function TweenFunction(tweenInfo, callback, bindTo)
	local trove = Trove.new()

	local t = trove:Add(Instance.new("NumberValue"))
	t.Value = 0

	local tween = TweenService:Create(t, tweenInfo, { Value = 1 })

	local function play()
		trove:Add(RunService.Heartbeat:Connect(function()
			callback(t.Value)
		end))
		tween:Play()

		return Promise.new(function(resolve, reject, onCancel)
			onCancel(function()
				trove:Clean()
				tween:Cancel()
			end)

			trove:Add(tween.Completed:Connect(function()
				resolve()
				trove:Clean()
			end))
		end)
	end

	return play
end

-- enums
local States = {
	Updating = "Updating",
	Idle = "Idle",
	Moving = "Moving",
	Rotating = "Rotating",
	Painting = "Painting",
	Referencing = "Referencing",
	Resizing = "Resizing",
}
local Gizmos = {
	Transform = "Transform",
	Scale = "Scale",
}
local MoveStatuses = {
	Moved = "Moved",
	InvalidPlacement = "InvalidPlacement",
	Discarded = "Discarded",
}

local Player = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local Mouse = Input.Mouse.new()
local mouseTouch = MouseTouch.new({
	Gui = false,
	Thumbstick = true,
	Unprocessed = true,
})
local mouseTouchGui = MouseTouch.new({
	Gui = true,
	Thumbstick = true,
	Unprocessed = true,
})

local ModelEditorController = {}
local self = ModelEditorController

function ModelEditorController.GameInit()
	-- Private Vars
	self._Active = Property.new(false)
	self._ActiveTrove = Trove.new()
	self._State = Property.new()
	self._RunningStatePromise = nil
	self._ActiveGizmo = Property.new(nil)
	self._ShowGizmos = Property.new(false)
	self._SelectedModel = Property.new()
	self._FakeCursorPart = Property.new(nil)
	self._IsDiscarding = Property.new(false)
	self._Config = {}
	self._UndoSteps = {}
	self._CurrentUndoStepIndex = 0
	self._LockCamera = Property.new(false)

	-- Public Vars
	self.Active = Property.ReadOnly(self._Active)
	self.State = Property.ReadOnly(self._State)
	self.SelectedModel = Property.ReadOnly(self._SelectedModel)
	self.IsDiscarding = Property.ReadOnly(self._IsDiscarding)
	self.SelectedMaterial = Property.new()
	self.ConfigName = Property.new()
	self.LockCamera = Property.ReadOnly(self._LockCamera)

	self.Instances = ModelEditorController._GetInstances()
end

function ModelEditorController.Start(configName)
	local function setConfig(config)
		self._Config = {}
		self._Config.Name = configName
		self._Config.IdleSelectionEnabled = DefaultValue(config.Client.IdleSelectionEnabled, true)
		self._Config.MultiplayerEdit = DefaultValue(config.Client.MultiplayerEdit, true)

		local instances = config.Client.Instances()
		self._Config.BuildPlatform = config.Client.GetBuildPlatform()
		self._Config.CameraPivot = RequiredValue(instances.CameraPivot)

		self._Config.Funcs = {}
		self._Config.Funcs.IsValidModel = RequiredValue(config.IsValidModel)
		self._Config.Funcs.GetModelFromPart = RequiredValue(config.GetModelFromPart)
		self._Config.Funcs.CanPaint = RequiredValue(config.Client.CanPaint)
		self._Config.Funcs.CanPlace = DefaultValue(config.CanPlace, SimpleFuncs.True())
		self._Config.Funcs.CanDiscard = DefaultValue(config.Client.CanDiscard, SimpleFuncs.False())
		self._Config.Funcs.GetLoadData = DefaultValue(config.Client.GetLoadData, SimpleFuncs.Nil())
		self._Config.Funcs.SaveData = DefaultValue(config.Client.SaveData, SimpleFuncs.Nil())
		self._Config.Funcs.OnUpdate = DefaultValue(config.Client.OnUpdate, SimpleFuncs.Nil())
		table.freeze(self._Config)
	end

	-- assert model editor is not already running
	assert(not self.Active:Get(), "Model Editor already active")
	ModelEditorController._AssertStatePromiseNotRunning()

	-- set active
	self._Active:Set(true)
	self._ActiveTrove:Add(function()
		self._Active:Set(false)
	end)

	-- set config
	assert(configName and ModelEditorConfigs[configName], tostring(configName) .. " is an unknown config name")
	setConfig(ModelEditorConfigs[configName])

	ModelEditorController.Load()

	-- setup props
	self._State:Set(nil)
	self._NeedToUpdate = {}
	self._RunningStatePromise = nil
	self._ActiveGizmo:Set(Gizmos.Transform)
	self.SelectedMaterial:Set(nil)
	self._FakeCursorPart:Set(nil)
	self._IsDiscarding:Set(false)
	self._LockCamera:Set(false)
	ModelEditorController.SelectModel(nil)

	-- setup undo steps
	self._UndoSteps = {}
	self._CurrentUndoStepIndex = 0
	ModelEditorController._AddUndoStep()

	ModelEditorController.StartIdleMode()

	ModelEditorController._SetupGizmos(self._ActiveTrove)
	ModelEditorController._SetupFakeCursor(self._ActiveTrove)
end

function ModelEditorController.Stop()
	if self._Active:Get() then
		ModelEditorController.Save()
		self._ActiveTrove:Clean()
	else
		error("Model Editor Controller already stopped")
	end
end

-- MODES

function ModelEditorController.StartIdleMode()
	ModelEditorController._AssertStatePromiseNotRunning()
	assert(self._State:Get() ~= States.Idle, "State is already idle")

	-- init the trove
	local toolTrove = self._ActiveTrove:Extend()

	-- set state
	self._State:Set(States.Idle)

	-- if the state changes, clean the trove
	toolTrove:Add(self.State.Changed:Connect(function()
		toolTrove:Clean()
	end))

	-- enable gizmos
	self._ShowGizmos:Set(true)

	-- add or reload undo step
	if ModelEditorController._VerifyModels() then
		ModelEditorController._AddUndoStep()
	else
		ModelEditorController._LoadCurrentUndoStep()
	end

	-- setup model click detector
	local modelClickDetector = toolTrove:Add(ClickDetector.new())
	ClickDetector.Name = "model"
	modelClickDetector.MouseIcon = MouseIcons.GrabOpen
	modelClickDetector:SetResultFilterFunction(function(result)
		local model = self._Config.Funcs.GetModelFromPart(result.Instance)
		return model
			and ModelEditorUtils.CanPlace(Player, self._Config.Funcs.CanPlace, model, model:GetPivot(), result.Instance)
	end)

	-- create a highlight
	local Highlight = toolTrove:Add(Instance.new("Highlight"))
	Highlight.FillTransparency = 1
	Highlight.OutlineColor = Color3.new(1, 1, 1)

	-- highlight the hovering part
	toolTrove:Add(modelClickDetector.HoveringPart:Observe(function(hoveringPart)
		if not Highlight then -- ensure highlight didn't get cleaned up
			return
		end

		local decorModel = self._Config.Funcs.GetModelFromPart(hoveringPart)
		if decorModel == self._SelectedModel:Get() then
			Highlight.Parent = nil
		else
			Highlight.Parent = decorModel
		end
	end))

	-- when mouse down on a valid model, then select it, and if the mouse moves, then move it
	local mouseDownTrove = toolTrove:Extend()
	toolTrove:Add(mouseTouch.LeftDown:Connect(function()
		mouseDownTrove:Add(mouseTouch.LeftUp:Connect(function()
			mouseDownTrove:Clean()
		end))

		Highlight.Parent = nil

		local part = modelClickDetector:GetBasePart()

		if part then
			local model = self._Config.Funcs.GetModelFromPart(part)

			mouseDownTrove:Add(mouseTouch.LeftUp:Connect(function()
				ModelEditorController.SelectModel(model)
			end))

			-- Create a temporary drag instance solely to calculate the instance-based offset
			local tempDrag = GeometricDrag.new(model.PrimaryPart, mouseTouch)
			local mouseOffset = tempDrag:GetMouseOffset(model.PrimaryPart:GetPivot().Position)
			tempDrag:Destroy() -- Clean up instantly

			mouseDownTrove:Add(mouseTouch.Moved:Connect(function()
				ModelEditorController.SelectModel(model)
				ModelEditorController.StartSnapMovingTool(model, mouseOffset):finally(function()
					ModelEditorController.StartIdleMode()
				end)
			end))
		else
			-- if no model was clicked on, then check if we clicked on a gizmo
			local result = mouseTouch:Raycast(ClickDetector.RaycastParams)

			if result.Instance and InstanceUtils.FindFirstAncestorWithTag(result.Instance, "Gizmo") then
				Pass()
			else
				ModelEditorController.SelectModel(nil)
			end
		end
	end))
end

function ModelEditorController.StartResizingMode(model)
	ModelEditorController._AssertStatePromiseNotRunning()
	assert(self._State:Get() ~= States.Resizing, "State is already Resizing")

	-- init the trove
	local toolTrove = self._ActiveTrove:Extend()

	-- set state
	self._State:Set(States.Resizing)
	self._ShowGizmos:Set(false)

	-- if the state changes, clean the trove
	toolTrove:Add(self.State.Changed:Connect(function()
		toolTrove:Clean()
	end))

	local allModels = self.Instances.ModelsFolder:GetChildren()

	-- save the original weld
	local weldedPart = ModelEditorUtils.GetWeldedPart(model)
	ModelEditorUtils.BreakWeld(model)

	model.PrimaryPart.Anchored = true

	local attached = WeldUtils.GetAttachedParts(model.PrimaryPart)

	local attachedModels = {}
	for _, part in attached do
		local attachedModel = self._Config.Funcs.GetModelFromPart(part)
		if attachedModel ~= model then
			attachedModels[attachedModel] = true
		end
	end

	for attachedModel, _ in attachedModels do
		attachedModel.Parent = model
	end

	toolTrove:Add(function()
		for attachedModel, _ in attachedModels do
			attachedModel.Parent = self.Instances.ModelsFolder
		end

		model.PrimaryPart.Anchored = false
		ModelEditorUtils.PlaceOn(model, weldedPart)
	end)

	ModelEditorController._HighlightInvalidModels(toolTrove, allModels)
end

function ModelEditorController.StartPaintMode(startingPart)
	ModelEditorController._AssertStatePromiseNotRunning()
	assert(self._State:Get() ~= States.Painting, "State is already Painting")

	-- init the trove
	local toolTrove = self._ActiveTrove:Extend()

	-- set state
	self._State:Set(States.Painting)

	-- if the state changes, clean the trove
	toolTrove:Add(self.State.Changed:Connect(function()
		toolTrove:Clean()
	end))

	-- enable gizmos
	self._ShowGizmos:Set(false)

	-- set starting part
	if not startingPart then
		startingPart = if self.SelectedModel:Get() then self.SelectedModel:Get().PrimaryPart else nil
	end

	if startingPart then
		self.SelectedMaterial:Set(CustomMaterial.new(startingPart))
	end

	-- create a highlight
	local Highlight = toolTrove:Add(Instance.new("Highlight"))
	Highlight.FillTransparency = 0.5
	Highlight.FillColor = Color3.new(1, 1, 1)
	Highlight.OutlineTransparency = 1

	local clickDetector = toolTrove:Add(ClickDetector.new())
	clickDetector:SetResultFilterFunction(function(result)
		return ModelEditorController.CanPaintInst(result.Instance)
	end)

	-- highlight the hovering part
	toolTrove:Add(clickDetector.HoveringPart:Observe(function(hoveringPart)
		local activePart = if self.SelectedMaterial:Get() then self.SelectedMaterial:Get():GetBasePart() else nil
		if hoveringPart == activePart then
			Highlight.Parent = nil
		else
			Highlight.Parent = hoveringPart
		end
	end))

	toolTrove:Add(clickDetector.LeftClick:Connect(function(part)
		self.SelectedMaterial:Set(CustomMaterial.new(part))
		Highlight.Parent = nil
	end))

	toolTrove:Add(function()
		if self.SelectedMaterial:Get() then
			ModelEditorController.SelectModel(
				self._Config.Funcs.GetModelFromPart(self.SelectedMaterial:Get():GetBasePart())
			)
		end
	end)
end

-- TOOLS

function ModelEditorController.StartSnapMovingTool(model, mouseOffset: Vector2?, recalculatePivot: boolean)
	local promise
	promise = Promise.new(function(resolve, reject, onCancel)
		ModelEditorController._AssertStatePromiseNotRunning()
		Assert(self._Config.Funcs.IsValidModel(Player, model), model, "is not a valid model")

		-- set the state
		self._State:Set(States.Moving)

		-- hide the gizmos
		self._ShowGizmos:Set(false)

		-- init the trove
		local toolTrove = self._ActiveTrove:Extend()

		-- TODO lock the camera

		-- Initialize drag detector FIRST so we can use its instance methods
		-- Pass mouseTouch into the constructor to ensure standard configuration matching
		local geometricDrag = toolTrove:Add(GeometricDrag.new(model.PrimaryPart, mouseTouch))

		-- get the grab offset via the instance method now
		mouseOffset = mouseOffset or geometricDrag:GetMouseOffset(model.PrimaryPart:GetPivot().Position)

		-- set the mouse icon
		self._FakeCursorPart:Set(model.PrimaryPart)
		toolTrove:Add(function()
			self._FakeCursorPart:Set(nil)
		end)

		-- disable weld
		ModelEditorUtils.RequireWeld(model)
		ModelEditorUtils.BreakWeld(model)

		-- parent all attached models to the model
		local attachedModels = ModelEditorController._GetAttachedModels(model)
		for _, attachedModel in attachedModels do
			attachedModel.Parent = model
		end
		toolTrove:Add(function()
			if model.Parent then
				for _, attachedModel in attachedModels do
					attachedModel.Parent = self.Instances.ModelsFolder
				end
			end
		end)

		-- init raycast params
		local raycastParams = RaycastUtils.CopyRaycastParams(ClickDetector.RaycastParams)
		assert(raycastParams.FilterType == Enum.RaycastFilterType.Exclude, "Click detector filter type must be exclude")
		raycastParams:AddToFilter(model)

		-- get starting info
		local originalCFrame = model:GetPivot()
		local originalWeldedPart = ModelEditorUtils.GetWeldedPart(model)

		local DiscardModelHighlight = toolTrove:Add(Instance.new("Highlight"))
		DiscardModelHighlight.OutlineColor = Color3.new(0.486274, 0.521568, 1)
		DiscardModelHighlight.FillColor = Color3.new(0.486274, 0.521568, 1)
		DiscardModelHighlight.FillTransparency = 0.5
		DiscardModelHighlight.Enabled = true

		local function snapmove()
			local mousePos = mouseOffset + mouseTouch:GetPosition()
			local result = mouseTouch:Raycast(raycastParams, nil, mousePos)
			local cframe

			if result then
				cframe = CFrame.lookAlong(result.Position, result.Normal, Vector3.xAxis)
					* CFrame.Angles(math.rad(-90), 0, 0)
			else
				local mouseRay = Mouse:GetRay()
				cframe = CFrame.new(mouseRay.Origin + mouseRay.Direction * 10)
			end

			return cframe, result
		end

		-- get part's initial rotation
		local rotation
		if recalculatePivot then
			rotation = CFrame.new()
		else
			local defualtCFrame, _ = snapmove()
			defualtCFrame = defualtCFrame.Rotation

			rotation = defualtCFrame:ToObjectSpace(originalCFrame.Rotation)
		end

		-- set drag style
		local result
		geometricDrag:SetDragStyle(function()
			local cframe
			cframe, result = snapmove()

			cframe *= rotation

			if self._Config.Funcs.CanDiscard(model, Mouse:GetPosition()) then
				DiscardModelHighlight.Parent = model
				model.Parent = self.Instances.ViewPortFrame.WorldModel
				self._IsDiscarding:Set(true)

				local mouseRay = Mouse:GetRay()

				local mouseHit = Vector3Utils.LineToPlaneIntersection(
					mouseRay.Origin,
					mouseRay.Direction,
					model:GetPivot().Position,
					CurrentCamera.CFrame.LookVector
				)
				cframe = CFrame.lookAlong(mouseHit, CurrentCamera.CFrame.LookVector)
			else
				DiscardModelHighlight.Parent = nil
				model.Parent = self.Instances.ModelsFolder
				self._IsDiscarding:Set(false)
			end

			return cframe
		end)

		-- start dragging
		geometricDrag:StartDrag()

		ModelEditorController._HighlightInvalidModels(toolTrove)

		toolTrove:Add(function()
			self._IsDiscarding:Set(false)
		end)

		-- tool finishes when mouse up
		toolTrove:Add(mouseTouchGui.LeftUp:Connect(function()
			geometricDrag:StopDrag()
			if self._IsDiscarding:Get() then
				ModelEditorController.DestroyModel(model)
			else
				ModelEditorUtils.PlaceOn(model, result.Instance)
			end

			toolTrove:Clean()
			resolve()
		end))
	end)
	self._RunningStatePromise = promise
	return promise
end

function ModelEditorController.StartRotatingTool(model, axis)
	local promise
	promise = Promise.new(function(resolve, reject, onCancel)
		ModelEditorController._AssertStatePromiseNotRunning()
		Assert(self._Config.Funcs.IsValidModel(Player, model), model, "is not a valid model")

		-- set the state
		self._State:Set(States.Moving)

		-- hide the gizmos
		self._ShowGizmos:Set(false)

		-- init the trove
		local toolTrove = self._ActiveTrove:Extend()

		-- set the mouse icon
		ClickDetector.OverrideIcon = MouseIcons.GrabClosed
		toolTrove:Add(function()
			ClickDetector.OverrideIcon = nil
		end)

		-- TODO lock the camera

		-- create a highlight
		local Highlight = toolTrove:Add(Instance.new("Highlight"))
		Highlight.OutlineColor = Color3.new(1, 0.486274, 0.486274)
		Highlight.FillTransparency = 0.5
		Highlight.Parent = model
		Highlight.Enabled = false

		-- create weld if neccessary
		ModelEditorUtils.RequireWeld(model)

		-- get starting info
		local initialPivot = model:GetPivot()
		local originalWeldedPart = ModelEditorUtils.GetWeldedPart(model)
		local initialMouseRay = mouseTouch:GetRay()

		-- disable weld
		ModelEditorUtils.BreakWeld(model)

		-- turn off collisions after we disabled the weld
		local attachedParts = WeldUtils.GetAttachedParts(model.PrimaryPart)
		ModelEditorController._ToggleCollisions(attachedParts, false)
		toolTrove:Add(function()
			ModelEditorController._ToggleCollisions(attachedParts, true)
		end)

		-- init drag detector, passing the mouseTouch instance
		local geometricDrag = toolTrove:Add(GeometricDrag.new(model.PrimaryPart, mouseTouch))

		-- set drag style
		geometricDrag:SetDragStyle(function()
			-- get rotate plane normal
			local rotatePlaneNormal = axis

			local function getPlaneHit(mouseRay)
				local worldHit = Vector3Utils.LineToPlaneIntersection(
					mouseRay.Origin,
					mouseRay.Direction,
					initialPivot.Position,
					rotatePlaneNormal
				)

				return worldHit
			end

			local ray = mouseTouch:GetRay()
			local currentPlaneHit = getPlaneHit(ray)
			local initialPlaneHit = getPlaneHit(initialMouseRay)

			local initialVector = (initialPlaneHit - initialPivot.Position).Unit
			local currentVector = (currentPlaneHit - initialPivot.Position).Unit

			-- Ensure vectors are not zero before calculating rotation
			if initialVector.Magnitude > 1e-6 and currentVector.Magnitude > 1e-6 then
				local relativeRotation =
					Vector3Utils.GetRotationBetweenVectors(initialVector, currentVector, rotatePlaneNormal)
				return CFrame.new(initialPivot.Position) * relativeRotation * initialPivot.Rotation
			end

			return nil
		end)

		-- start dragging
		geometricDrag:StartDrag()

		ModelEditorController._HighlightInvalidModels(toolTrove)

		-- tool finishes when mouse up
		toolTrove:Add(mouseTouchGui.LeftUp:Connect(function()
			geometricDrag:StopDrag()
			ModelEditorUtils.PlaceOn(model, originalWeldedPart)
			toolTrove:Clean()
			resolve(MoveStatuses.Moved)
		end))
	end)
	self._RunningStatePromise = promise
	return promise
end

function ModelEditorController.StartArcballRotatingTool(model, arcballRadius, mouseOffset)
	local function rotateArcball(initialPivot)
		local mouseRay = mouseTouch:GetRay()

		local points = Vector3Utils.ClosestPointsOnSphereToLine(
			mouseRay.Origin,
			mouseRay.Direction,
			initialPivot.Position,
			arcballRadius
		)

		local closestPointOnSphere = TableUtil2.Best(points, function(pt1, pt2)
			return (pt1 - mouseRay.Origin).Magnitude < (pt2 - mouseRay.Origin).Magnitude
		end)

		return CFrame.lookAt(initialPivot.Position, closestPointOnSphere, CurrentCamera.CFrame.RightVector)
			* CFrame.fromEulerAnglesXYZ(math.rad(-90), 0, 0)
	end

	local promise
	promise = Promise.new(function(resolve, reject, onCancel)
		ModelEditorController._AssertStatePromiseNotRunning()
		Assert(self._Config.Funcs.IsValidModel(Player, model), model, "is not a valid model")

		-- set the state
		self._State:Set(States.Moving)

		-- hide the gizmos
		self._ShowGizmos:Set(true)

		-- init the trove
		local toolTrove = self._ActiveTrove:Extend()

		-- set the mouse icon
		ClickDetector.OverrideIcon = MouseIcons.GrabClosed
		toolTrove:Add(function()
			ClickDetector.OverrideIcon = nil
		end)

		-- TODO lock the camera

		-- create a highlight
		local Highlight = toolTrove:Add(Instance.new("Highlight"))
		Highlight.OutlineColor = Color3.new(1, 0.486274, 0.486274)
		Highlight.FillTransparency = 0.5
		Highlight.Parent = model
		Highlight.Enabled = false

		-- create weld if neccessary
		ModelEditorUtils.RequireWeld(model)

		-- get starting info
		local initialPivot = model:GetPivot()
		local originalWeldedPart = ModelEditorUtils.GetWeldedPart(model)

		local rotationOffset = rotateArcball(initialPivot):ToObjectSpace(initialPivot)

		-- disable weld
		ModelEditorUtils.BreakWeld(model)

		-- turn off collisions after we disabled the weld
		local attachedParts = WeldUtils.GetAttachedParts(model.PrimaryPart)
		ModelEditorController._ToggleCollisions(attachedParts, false)
		toolTrove:Add(function()
			ModelEditorController._ToggleCollisions(attachedParts, true)
		end)

		-- init drag detector, passing mouseTouch configuration
		local geometricDrag = toolTrove:Add(GeometricDrag.new(model.PrimaryPart, mouseTouch))

		-- set drag style
		geometricDrag:SetDragStyle(function()
			return rotateArcball(initialPivot) * rotationOffset
		end)

		-- start dragging
		geometricDrag:StartDrag()

		ModelEditorController._HighlightInvalidModels(toolTrove)

		-- tool finishes when mouse up
		toolTrove:Add(mouseTouchGui.LeftUp:Connect(function()
			geometricDrag:StopDrag()
			ModelEditorUtils.PlaceOn(model, originalWeldedPart)
			toolTrove:Clean()
			resolve(MoveStatuses.Moved)
		end))
	end)
	self._RunningStatePromise = promise
	return promise
end

function ModelEditorController.PlaceModel(assetName)
	return Promise.new(function(resolve)
		ModelEditorController._AssertStatePromiseNotRunning()

		local newModel = self._ActiveTrove:Add(ModelEditorUtils.CreateModel(assetName))
		newModel:SetAttribute("IsLocal", true) -- debugging use
		newModel.Parent = self.Instances.ModelsFolder
		newModel.Name = HttpService:GenerateGUID(false)

		-- set the newModel's cframe
		local result = mouseTouch:Raycast(ClickDetector.RaycastParams)
		local cframe
		if result then
			cframe = CFrame.new(result.Position)
		else
			local mouseRay = mouseTouch:GetRay()
			cframe = CFrame.new(mouseRay.Origin + mouseRay.Direction.Unit)
		end
		newModel:PivotTo(cframe)

		ModelEditorController.StartSnapMovingTool(newModel, nil, true):finally(function()
			if newModel.Parent then
				ModelEditorController.SelectModel(newModel)
			end

			ModelEditorController.StartIdleMode()
		end)
	end)
end

function ModelEditorController.DestroyModel(model)
	if self._SelectedModel:Get() == model then
		ModelEditorController.SelectModel(nil)
	end

	model:Destroy()
end

-- Gizmos

function ModelEditorController._SetupGizmos(trove)
	local gizmoTrove = trove:Extend()
	local function updateGizmo()
		gizmoTrove:Clean()

		local model = self.SelectedModel:Get()
		if (not self._ShowGizmos:Get()) or not model then
			Pass()
		elseif self._ActiveGizmo:Get() == Gizmos.Transform then
			ModelEditorController._SetupTransformGizmo(gizmoTrove, model)
		elseif self._ActiveGizmo:Get() == Gizmos.Scale then
			ModelEditorController._SetupScaleGizmo(gizmoTrove, model)
		end
	end

	trove:Add(self._ShowGizmos:Observe(updateGizmo))
	trove:Add(self._ActiveGizmo:Observe(updateGizmo))
	trove:Add(self.SelectedModel:Observe(updateGizmo))
end

function ModelEditorController._ScaleGizmo(gizmo, model, useTween)
	local modelSize = (model:GetExtentsSize() - model.PrimaryPart.PivotOffset.Position) * 1.5
	local maxXYZ = math.max(modelSize.X, modelSize.Y, modelSize.Z)

	if useTween then
		gizmo:ScaleTo(0.01)
		local promise = TweenFunction(TweenInfo.new(1, Enum.EasingStyle.Elastic), function(t)
			gizmo:ScaleTo(maxXYZ * t + 0.001)
		end)()

		return promise
	else
		gizmo:ScaleTo(maxXYZ + 0.001)
	end
end

function ModelEditorController._SetupTransformGizmo(gizmoTrove, model)
	local gizmo = self.Instances.TransformGizmo

	gizmo.Parent = workspace
	self.Instances.TransformGizmoBallGui.Adornee = gizmo.RotateBall
	gizmoTrove:Add(function()
		gizmo.Parent = nil
		self.Instances.TransformGizmoBallGui.Adornee = nil
	end)

	gizmoTrove:AddPromise(ModelEditorController._ScaleGizmo(gizmo, model, true))

	local function UpdateGizmoVisuals()
		-- updatge gizmo cframe
		gizmo:PivotTo(self.SelectedModel:Get():GetPivot())

		-- update gizmo ball size
		local ballSize = gizmo.RotateBall.Size.X
		self.Instances.TransformGizmoBallGui.Size = UDim2.fromScale(ballSize, ballSize)
	end

	UpdateGizmoVisuals()
	gizmoTrove:Add(RunService.RenderStepped:Connect(UpdateGizmoVisuals))

	local gizmoClickDetector = gizmoTrove:Add(ClickDetector.new())
	gizmoClickDetector:SetResultFilterFunction(function(result)
		return result.Instance.Parent == gizmo
	end)
	gizmoClickDetector.MouseIcon = MouseIcons.Rotate

	-- when gizmo ring is pressed, rotate model
	gizmoTrove:Add(gizmoClickDetector.LeftDown:Connect(function(part, result)
		if part == gizmo.YBounds then
			ModelEditorController.StartRotatingTool(model, model:GetPivot().UpVector):finally(function()
				ModelEditorController.StartIdleMode()
			end)
		end
	end))

	-- when gizmo ball is pressed, rotate model arcball style
	gizmoTrove:Add(self.Instances.TransformGizmoBallGui.Button.MouseButton1Down:Connect(function()
		local rotateballDistance = (gizmo.RotateBall.Position - gizmo.Pivot.Position).Magnitude

		-- Create a temporary drag instance to grab our relative mouse offset
		local tempDrag = GeometricDrag.new(gizmo.PrimaryPart, mouseTouch)
		local mouseOffset = tempDrag:GetMouseOffset(gizmo.Pivot.Position)
		tempDrag:Destroy()

		ModelEditorController.StartArcballRotatingTool(model, rotateballDistance, mouseOffset):finally(function()
			ModelEditorController.StartIdleMode()
		end)
	end))
end

function ModelEditorController._SetupScaleGizmo(gizmoTrove, model)
	local gizmo: Handles = self.Instances.ScaleGizmo
	gizmo.Adornee = model.PrimaryPart

	gizmoTrove:Add(function()
		gizmo.Adornee = nil
	end)

	local movingTrove = gizmoTrove:Extend()
	gizmoTrove:Add(gizmo.MouseButton1Down:Connect(function()
		model.PrimaryPart.Anchored = true
		local weldedPart = ModelEditorUtils.GetWeldedPart(model)
		ModelEditorUtils.BreakWeld(model)

		movingTrove:Add(function()
			model.PrimaryPart.Anchored = false
			ModelEditorUtils.PlaceOn(model, weldedPart)
		end)

		movingTrove:Add(gizmo.MouseButton1Up:Connect(function()
			movingTrove:Clean()
		end))
	end))

	local totalDistance = 0

	local lastDistance = 0
	gizmoTrove:Add(gizmo.MouseDrag:Connect(function(face: Enum.NormalId, distance)
		local distanceDelta = distance - lastDistance
		totalDistance += distance

		local scale = Vector3.new(distance, 0, 0)
		if face == Enum.NormalId.Left then
			scale = Vector3.new(distance, 0, 0)
		end
		ModelUtils.ScaleToPivot(model, 1 + distanceDelta)
	end))
end

-- Undos

function ModelEditorController.Undo()
	if self._CurrentUndoStepIndex > 1 then
		self._CurrentUndoStepIndex -= 1
		ModelEditorController._LoadCurrentUndoStep()
	end
end

function ModelEditorController.Redo()
	if self._CurrentUndoStepIndex < #self._UndoSteps then
		self._CurrentUndoStepIndex += 1
		ModelEditorController._LoadCurrentUndoStep()
	end
end

function ModelEditorController._AddUndoStep()
	if #self._UndoSteps > 0 then
		self._UndoSteps = TableUtil.Truncate(self._UndoSteps, self._CurrentUndoStepIndex)
	end

	self._CurrentUndoStepIndex += 1
	self._UndoSteps[self._CurrentUndoStepIndex] = self.Instances.ModelsFolder:Clone()

	self._Config.Funcs.OnUpdate(self.Instances.ModelsFolder:GetChildren())
end

function ModelEditorController._LoadCurrentUndoStep()
	Assert(
		self._UndoSteps[self._CurrentUndoStepIndex],
		"Undo step not found",
		self._CurrentUndoStepIndex,
		self._UndoSteps
	)
	self.Instances.ModelsFolder:Destroy()
	ModelEditorController.SelectModel(nil)
	self.Instances.ModelsFolder = self._UndoSteps[self._CurrentUndoStepIndex]:Clone()
	self.Instances.ModelsFolder.Parent = workspace

	for _, model in self.Instances.ModelsFolder:GetChildren() do
		self._ActiveTrove:Add(model)
	end

	self._Config.Funcs.OnUpdate(self.Instances.ModelsFolder:GetChildren())
end

-- Public Utils

function ModelEditorController.ScaleTo(model, scale: number)
	assert(self.State:Get() == States.Resizing, "Mode must be resizing")
	model:ScaleTo(scale)
end

function ModelEditorController.SelectModel(model)
	Assert(model == nil or self._Config.Funcs.IsValidModel(Player, model), model, " is not a valid model")
	self._SelectedModel:Set(model)
end

function ModelEditorController.SelectMaterialFromPart(part: BasePart)
	Assert(ModelEditorController.CanPaintInst(part), "can't paint", part)

	ModelEditorController.SelectedMaterial:Set(CustomMaterial.new(part))
end

function ModelEditorController.CanPaintInst(inst)
	if inst == nil or not inst:IsA("BasePart") then
		return false
	end

	local model = self._Config.Funcs.GetModelFromPart(inst)
	return model
		and ModelEditorUtils.CanPlace(Player, self._Config.Funcs.CanPlace, model, nil, nil)
		and self._Config.Funcs.CanPaint(inst)
end

function ModelEditorController.GetDataWithoutSaving()
	return ModelEditorUtils.Save(self._Config.BuildPlatform, self.Instances.ModelsFolder)
end

function ModelEditorController.Save()
	local saveData = ModelEditorController.GetDataWithoutSaving()
	self._Config.Funcs.SaveData(saveData)
	return saveData
end

function ModelEditorController.Load(loadData)
	loadData = loadData or self._Config.Funcs.GetLoadData()
	if loadData then
		local models = ModelEditorUtils.Load(self._Config.BuildPlatform, self.Instances.ModelsFolder, loadData)
		for _, model in models do
			self._ActiveTrove:Add(model)
		end
	end
	ModelEditorController._AddUndoStep()
end

function ModelEditorController.Clean()
	for _, model in self.Instances.ModelsFolder do
		model:Destroy()
	end
	ModelEditorController._AddUndoStep()
end

-- Private Utils

function ModelEditorController._AssertStatePromiseNotRunning()
	Assert(
		self._RunningStatePromise == nil or self._RunningStatePromise:getStatus() ~= "Started",
		self._State:Get(),
		" has not finished running",
		self._RunningStatePromise,
		if self._RunningStatePromise then self._RunningStatePromise:getStatus() else nil
	)
end

function ModelEditorController._ToggleCollisions(parts, toggle)
	local OriginalCanCollideAttributeName = "ModelEditor_OriginalCanCollide"
	for _, part in pairs(parts) do
		if toggle then
			part.CanCollide = DefaultValue(part:GetAttribute(OriginalCanCollideAttributeName), true)
		else
			part:SetAttribute(OriginalCanCollideAttributeName, part.CanCollide)
			part.CanCollide = false
		end
	end
end

function ModelEditorController._SetupFakeCursor(trove)
	local cursorPartTrove = trove:Extend()
	local FakeCursor = self.Instances.FakeCursor

	trove:Add(self._FakeCursorPart:Observe(function(part: BasePart)
		cursorPartTrove:Clean()

		if part then
			ClickDetector:ToggleCursorVisibility(false)
			FakeCursor.Visible = true

			cursorPartTrove:Add(function()
				ClickDetector:ToggleCursorVisibility(true)
				FakeCursor.Visible = false
			end)

			local function moveCursorToPartPos()
				local screenPosition = CurrentCamera:WorldToViewportPoint(part:GetPivot().Position)
				FakeCursor.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
			end

			moveCursorToPartPos()
			cursorPartTrove:Add(RunService.RenderStepped:Connect(moveCursorToPartPos))
		end
	end))
end

function ModelEditorController._VerifyModels()
	for _, model in self.Instances.ModelsFolder:GetChildren() do
		if not ModelEditorUtils.CanPlace(Player, self._Config.Funcs.CanPlace, model, nil, nil) then
			return false
		end
	end

	return true
end

function ModelEditorController._HighlightInvalidModels(trove, models)
	models = models or self.Instances.ModelsFolder:GetChildren()

	local highlightTrove = trove:Extend()
	trove:Add(RunService.RenderStepped:Connect(function()
		highlightTrove:Clean()

		for _, model in models do
			if not ModelEditorUtils.CanPlace(Player, self._Config.Funcs.CanPlace, model, nil, nil) then
				local highlight = highlightTrove:Add(self.Instances.InvalidModelHighlight:Clone())
				highlight.Parent = model
			end
		end
	end))
end

function ModelEditorController._GetInstances()
	local ModelsFolder = Instance.new("Folder")
	ModelsFolder.Name = "ModelEditorModels"
	ModelsFolder.Parent = workspace

	local InvalidModelHighlight = Instance.new("Highlight")
	InvalidModelHighlight.OutlineColor = Color3.new(1, 0.486274, 0.486274)
	InvalidModelHighlight.FillTransparency = 0.5
	InvalidModelHighlight.Enabled = true

	local TransformGizmo =
		ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Extras"):WaitForChild("ModelEditorGizmo")
	TransformGizmo.RotateBall.Transparency = 1
	TransformGizmo.PrimaryPart.Anchored = true

	-- guis
	local ModelEditorCoreGui = Player.PlayerGui:WaitForChild("ModelEditorCoreGuis"):WaitForChild("ModelEditorCoreGui")
	ModelEditorCoreGui.Enabled = true

	local FakeCursor = ModelEditorCoreGui:WaitForChild("FakeCursor")
	FakeCursor.Visible = false

	local ViewPortFrame = ModelEditorCoreGui:WaitForChild("ViewportFrame")
	ViewPortFrame.CurrentCamera = CurrentCamera

	local ScaleGizmo = ModelEditorCoreGui:WaitForChild("ScaleGizmo")
	local TransformGizmoBallGui =
		Player.PlayerGui:WaitForChild("ModelEditorCoreGuis"):WaitForChild("TransformGizmoBallGui")
	TransformGizmoBallGui.Enabled = true

	-- add all instances to table
	local instances = {}
	instances.FakeCursor = FakeCursor
	instances.ViewPortFrame = ViewPortFrame
	instances.ScaleGizmo = ScaleGizmo
	instances.TransformGizmoBallGui = TransformGizmoBallGui
	instances.TransformGizmo = TransformGizmo
	instances.ModelsFolder = ModelsFolder
	instances.InvalidModelHighlight = InvalidModelHighlight

	return instances
end

function ModelEditorController._GetAttachedModels(model)
	local attachedParts = WeldUtils.GetAttachedParts(model.PrimaryPart)
	local attachedModels = {}

	for _, part in attachedParts do
		local attachedModel = self._Config.Funcs.GetModelFromPart(part)
		if attachedModel and attachedModel ~= model then
			attachedModels[attachedModel] = true
		end
	end

	return TableUtil.Keys(attachedModels)
end

return ModelEditorController
