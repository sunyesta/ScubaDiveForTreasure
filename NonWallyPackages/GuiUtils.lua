-- UDimUtils
local UDimUtils = {}

function UDimUtils.ScaleToOffset(scale, parentGuiAbsoluteSize)
	return parentGuiAbsoluteSize * scale
end

function UDimUtils.OffsetToScale(offset, parentGuiAbsoluteSize)
	return offset / parentGuiAbsoluteSize
end

function UDimUtils.ToScale(udim, parentGuiAbsoluteSize)
	local finalScale = UDimUtils.OffsetToScale(udim.Offset, parentGuiAbsoluteSize)
	return UDim.new(udim.Scale + finalScale, 0)
end

function UDimUtils.ToOffset(udim, parentGuiAbsoluteSize)
	local finalOffset = UDimUtils.ScaleToOffset(udim.Scale, parentGuiAbsoluteSize)
	return UDim.new(0, udim.Offset + finalOffset)
end

-- UDim2Utils
local UDim2Utils = {}

function UDim2Utils.SeparateScaleOffset(udim2)
	local scale = Vector2.new(udim2.X.Scale, udim2.Y.Scale)
	local offset = Vector2.new(udim2.X.Offset, udim2.Y.Offset)
	return scale, offset
end

function UDim2Utils.ToScale(parentGuiAbsoluteSize, udim2)
	return UDim2.new(
		UDimUtils.ToScale(udim2.X, parentGuiAbsoluteSize.X),
		UDimUtils.ToScale(udim2.Y, parentGuiAbsoluteSize.Y)
	)
end

function UDim2Utils.ToOffset(parentGuiAbsoluteSize, udim2)
	return UDim2.new(
		UDimUtils.ToOffset(udim2.X, parentGuiAbsoluteSize.X),
		UDimUtils.ToOffset(udim2.Y, parentGuiAbsoluteSize.Y)
	)
end

-- Gui Utils

local GuiUtils = {}
GuiUtils.UDim2Utils = UDim2Utils
GuiUtils.UDimUtils = UDimUtils

-- anchor point is always calculated from top left automatically
function GuiUtils.AbsoluteToOffsetPosition(guiObject: GuiObject, absolutePosition: Vector2)
	-- Get the absolute position of the parent GUI object.  This is crucial!
	local parentAbsolutePosition = GuiUtils.GetParentAbsolutePosition(guiObject)

	-- Calculate the relative position.
	local relativePosition = absolutePosition + GuiUtils.GetAnchorOffset(guiObject) - parentAbsolutePosition

	return UDim2.fromOffset(relativePosition.X, relativePosition.Y)
end

function GuiUtils.AbsoluteToScalePosition(guiObject: GuiObject, absolutePosition: Vector2)
	return UDim2Utils.ToScale(
		GuiUtils.GetParentAbsoluteSize(guiObject),
		GuiUtils.AbsoluteToOffsetPosition(guiObject, absolutePosition)
	)
end

function GuiUtils.AbsoluteToScaleSize(guiObject: GuiObject, absoluteSize: Vector2)
	-- 1. Get the absolute pixel size of the parent (the container)
	local parentAbsoluteSize = GuiUtils.GetParentAbsoluteSize(guiObject)

	-- 2. Calculate the scale (0 to 1) by dividing the absoluteSize by the parent's size
	local scaleX = absoluteSize.X / parentAbsoluteSize.X
	local scaleY = absoluteSize.Y / parentAbsoluteSize.Y

	-- 3. Return a UDim2 with scale values and zero offset
	return UDim2.new(
		scaleX,
		0, -- X Scale and X Offset (0)
		scaleY,
		0 -- Y Scale and Y Offset (0)
	)
end

function GuiUtils.ToOffset(guiObject: GuiObject, udim2: UDim2)
	return UDim2Utils.ToOffset(guiObject.Parent, udim2)
end

function GuiUtils.GetParentAbsoluteSize(guiObject: GuiObject)
	local guiParent = guiObject:FindFirstAncestorWhichIsA("GuiObject")
	if guiParent then
		return guiParent.AbsoluteSize
	else
		return workspace.CurrentCamera.ViewportSize
	end
end

function GuiUtils.GetParentAbsolutePosition(guiObject: GuiObject)
	local guiParent = guiObject:FindFirstAncestorWhichIsA("GuiObject")
	if guiParent then
		return guiParent.AbsolutePosition
	else
		return Vector2.new(0, 0)
	end
end

function GuiUtils.GetAnchorOffset(guiObject: GuiObject)
	return Vector2.new(
		guiObject.AnchorPoint.X * guiObject.AbsoluteSize.X,
		guiObject.AnchorPoint.Y * guiObject.AbsoluteSize.Y
	)
end

function GuiUtils.PointInGui(guiObject: GuiObject, point)
	-- src: https://devforum.roblox.com/t/how-do-i-detect-if-the-mouse-is-inside-a-frame/1655611

	local function MouseBetweenPoints(pointA, pointB)
		local mouseVector = Vector2.new(point.X, point.Y)
		local pointAVector = Vector2.new(pointA.X.Offset, pointA.Y.Offset)
		local pointBVector = Vector2.new(pointB.X.Offset, pointB.Y.Offset)
		return (
			(mouseVector.X > pointAVector.X and mouseVector.Y > pointAVector.Y)
			and (mouseVector.X < pointBVector.X and mouseVector.Y < pointBVector.Y)
		)
	end

	local pointAVector = guiObject.AbsolutePosition
	local pointBVector = guiObject.AbsolutePosition + guiObject.AbsoluteSize
	return MouseBetweenPoints(
		UDim2.fromOffset(pointAVector.X, pointAVector.Y),
		UDim2.fromOffset(pointBVector.X, pointBVector.Y)
	)
end

function GuiUtils.GetGuiBaseSize(guiObject: GuiObject)
	local guiBase = guiObject:FindFirstAncestorWhichIsA("ScreenGui")
	return if guiBase then guiBase.AbsoluteSize else workspace.CurrentCamera.ViewportSize
end

return GuiUtils
