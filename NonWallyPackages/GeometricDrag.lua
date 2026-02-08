local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)
local MouseTouch = require(ReplicatedStorage.NonWallyPackages.MouseTouch)

local mouseTouch = MouseTouch.new()

-- Removed the global require of MouseTouch to prevent using the stateless class definition
-- local MouseTouch = require(ReplicatedStorage.NonWallyPackages.MouseTouch)

local Player = Players.LocalPlayer

local GeometricDrag = {}
GeometricDrag.__index = GeometricDrag

-- CHANGED: Added mouseTouch parameter to constructor
function GeometricDrag.new(part: BasePart)
	local self = setmetatable({}, GeometricDrag)

	-- private properties
	self._Trove = Trove.new()
	self._DragTrove = self._Trove:Extend()
	self._Part = part
	self._PhysicsConfig = nil

	-- Store the specific MouseTouch instance that tracks the active finger
	self._MouseTouch = mouseTouch

	-- Initialize DragStyle AFTER setting _MouseTouch so it can be used in the closure
	self._DragStyle = self:_MakeDefaultDragStyle()

	-- public properties
	self.DragStart = Signal.new()
	self.DragEnd = Signal.new()
	self.UnanchorOnDrop = false

	return self
end

function GeometricDrag:Destroy()
	self._Trove:Clean()
end

function GeometricDrag:SetDragStyle(dragStyle)
	self._DragStyle = dragStyle
end

function GeometricDrag:StartDrag()
	-- anchor part locally during drag to prevent physics interference
	local oldAnchored = self._Part.Anchored
	self._Part.Anchored = true
	self._DragTrove:Add(function()
		self._Part.Anchored = oldAnchored
	end)

	-- 1. Determine Exact Grab Point in World Space
	-- CHANGED: Use self._MouseTouch instance
	local mouseRay = self._MouseTouch:GetRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	-- Ensure we raycast against the entire model to find exactly what was clicked
	local model = self._Part:FindFirstAncestorWhichIsA("Model") or self._Part
	params.FilterDescendantsInstances = { model }

	local hit = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 2000, params)
	-- If we missed (rare, but possible), fallback to pivot
	local grabPoint = hit and hit.Position or self._Part:GetPivot().Position

	-- 2. Calculate World Offset (Vector from Grab Point -> Model Center)
	local pivotPos = self._Part:GetPivot().Position
	local centerOffset = pivotPos - grabPoint

	-- 3. Define a virtual plane at the grab height to stabilize dragging
	local planeY = grabPoint.Y

	-- move model to desired cframe
	local desiredCFrame = self._Part:GetPivot()
	self._DragTrove:Add(RunService.RenderStepped:Connect(function()
		-- 4. Calculate Virtual Mouse Position on the Plane
		-- CHANGED: Use self._MouseTouch instance
		local currentRay = self._MouseTouch:GetRay()

		-- Intersect Mouse Ray with horizontal Plane Y = planeY
		-- Formula: t = (TargetY - OriginY) / DirectionY
		local t = 0
		if math.abs(currentRay.Direction.Y) > 0.001 then
			t = (planeY - currentRay.Origin.Y) / currentRay.Direction.Y
		end

		local adjustedScreenPos

		if t > 0 then
			-- We hit the virtual plane
			local intersect = currentRay.Origin + currentRay.Direction * t

			-- Apply the offset to find where the Center should be if the Grab Point was at the mouse
			local desiredCenter = intersect + centerOffset

			-- Project that desired center back to screen coordinates for the DragStyle
			local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(desiredCenter)
			adjustedScreenPos = Vector2.new(screenPos.X, screenPos.Y)
		else
			-- Fallback (looking at horizon): Use raw mouse pos
			-- CHANGED: Use self._MouseTouch instance
			adjustedScreenPos = self._MouseTouch:GetPosition()
		end

		-- Calculate new CFrame based on that virtual position
		local newCFrame = self._DragStyle(adjustedScreenPos)

		if newCFrame then
			desiredCFrame = newCFrame
			-- Update the part's position with Lerp
			self._Part:PivotTo(self._Part:GetPivot():Lerp(desiredCFrame, 0.3))
		end
	end))

	self.DragStart:Fire()
end

function GeometricDrag:StopDrag()
	self._DragTrove:Clean()
	if self.UnanchorOnDrop then
		self._Part.Anchored = false
	end
	self.DragEnd:Fire()
end

function GeometricDrag:_MakeDefaultDragStyle()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { self._Part, Player.Character }

	return function(adjustedMousePos)
		-- Use the adjusted position for the ray
		-- CHANGED: Use self._MouseTouch instance
		local cursorRay = self._MouseTouch:GetRay(adjustedMousePos)
		local characterDistance = (cursorRay.Origin - Player.Character:GetPivot().Position).Magnitude

		-- Cast ray from the adjusted screen position
		local result = workspace:Raycast(cursorRay.Origin, cursorRay.Direction * 1000, raycastParams)

		local position = if result then result.Position else cursorRay.Origin + cursorRay.Direction * characterDistance
		return CFrame.new(position)
	end
end

-- CHANGED: Changed to instance method (colon :) to access self._MouseTouch
function GeometricDrag:GetMouseOffset(worldPosition)
	local modelScreenPos = workspace.CurrentCamera:WorldToViewportPoint(worldPosition)
	return Vector2.new(modelScreenPos.X, modelScreenPos.Y) - self._MouseTouch:GetPosition()
end

return GeometricDrag
