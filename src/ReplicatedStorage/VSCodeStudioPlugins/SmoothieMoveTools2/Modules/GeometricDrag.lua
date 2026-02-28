--!strict

local Trove = require(script.Parent.Trove)

local Signal = require(script.Parent.Signal)

local PluginMouse = require(script.Parent.PluginMouse)

local Workspace = game:GetService("Workspace")

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
	-- Clean up previous drag session if exists

	self._DragTrove:Clean()

	-- Anchor part temporarily

	local oldAnchored = self._Part.Anchored

	self._Part.Anchored = true

	self._DragTrove:Add(function()
		self._Part.Anchored = oldAnchored
	end)

	-- Get new mousePos offset

	self:UpdateMouseOffset()

	self.DragStart:Fire()
end

-- Returns the new mathematical CFrame if the parts should move, or nil.

function GeometricDrag:Step(currentMousePos: Vector2): CFrame?
	if not self._MouseOffset then
		return nil
	end

	local mousePosWithOffset = currentMousePos + self._MouseOffset

	local resultCFrame = self._DragStyle(mousePosWithOffset)

	return resultCFrame
end

function GeometricDrag:StopDrag()
	self._DragTrove:Clean()

	self.DragEnd:Fire()
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

function GeometricDrag.GetMouseOffset(part: BasePart)
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

		return if result then CFrame.new(result.Position, nil, adjustedMousePos) else nil
	end
end

return GeometricDrag
