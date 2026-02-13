local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)
local PluginMouse = require(script.Parent.PluginMouse)

local GeometricDrag = {}
GeometricDrag.__index = GeometricDrag

function GeometricDrag.new(part: BasePart)
	local self = setmetatable({}, GeometricDrag)

	-- private properties
	self._Trove = Trove.new()
	self._DragTrove = self._Trove:Extend()
	self._Part = part
	self._DragStyle = self:_MakeDefaultDragStyle()
	self._MouseOffset = nil

	-- public properties
	self.DragStart = Signal.new()
	self.DragEnd = Signal.new()

	return self
end
function GeometricDrag:Destroy()
	self._Trove:Clean()
end

function GeometricDrag:SetDragStyle(dragStyle)
	self._DragStyle = dragStyle
end

function GeometricDrag:StartDrag()
	self._DragTrove:Add(self:_StartDrag())
end

function GeometricDrag:StopDrag()
	self._DragTrove:Clean()
	self.DragEnd:Fire()
end

-- Local only! Does not update part's position on server!
function GeometricDrag:_StartDrag()
	local dragTrove = self._Trove:Extend()

	-- anchor part
	local oldAnchored = self._Part.Anchored
	self._Part.Anchored = true
	dragTrove:Add(function()
		self._Part.Anchored = oldAnchored
	end)

	-- get new mousePos
	self:UpdateMouseOffset()

	-- move model to desired cframe
	local desiredCFrame = self._Part:GetPivot()

	dragTrove:Add(RunService.RenderStepped:Connect(function()
		-- update the desired cframe
		local mousePosWithOffset = PluginMouse:GetPosition() + self._MouseOffset
		desiredCFrame = self._DragStyle(mousePosWithOffset) or desiredCFrame

		-- update the part's position
		self._Part:PivotTo(desiredCFrame)
	end))

	return dragTrove
end

function GeometricDrag:_MakeDefaultDragStyle()
	return function()
		return nil
	end
end

function GeometricDrag:UpdateMouseOffset()
	local modelScreenPos = Workspace.CurrentCamera:WorldToViewportPoint(self._Part:GetPivot().Position)
	self._MouseOffset = Vector2.new(modelScreenPos.X, modelScreenPos.Y) - PluginMouse:GetPosition()
end

function GeometricDrag.GetMouseOffset(part)
	local modelScreenPos = Workspace.CurrentCamera:WorldToViewportPoint(part:GetPivot().Position)
	return Vector2.new(modelScreenPos.X, modelScreenPos.Y) - PluginMouse:GetPosition()
end

GeometricDrag.DragStyles = {}

function GeometricDrag.DragStyles.Surface(ignoreParts)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { ignoreParts }

	return function(adjustedMousePos)
		local result = PluginMouse:Raycast(raycastParams)
		return if result then CFrame.new(PluginMouse:Raycast(raycastParams).Position, nil, adjustedMousePos) else nil
	end
end

return GeometricDrag
