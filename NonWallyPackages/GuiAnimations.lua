--! README: Out always makes gui object invisible. In always makes gui object visible
--! Also, don't use this on guis that are parented to moving guis
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)
local GuiUtils = require(ReplicatedStorage.NonWallyPackages.GuiUtils)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GuiAnimations = {}
GuiAnimations.DefaultTweenInfo = TweenInfo.new(0.3)
GuiAnimations._SavedPositionAttName = "GuiAnimations_SavedPosition"
GuiAnimations._SavedBackgroundTransparencyAttName = "GuiAnimations_SavedBackgroundTransparency"
GuiAnimations._SavedTextTransparencyAttName = "GuiAnimations_SavedTextTransparency"
GuiAnimations._SavedTextStrokeTransparencyAttName = "GuiAnimations_SavedTextStrokeTransparency"
GuiAnimations._SavedImageTransparencyAttName = "GuiAnimations_SavedImageTransparency"
GuiAnimations._SavedUIStrokeTransparencyAttName = "GuiAnimations_SavedUIStrokeTransparency"
GuiAnimations._SavedSizeAttName = "GuiAnimations_SavedSize"
GuiAnimations._SavedRotationAttName = "GuiAnimations_SavedRotation"
GuiAnimations._ScreenSides = {
	Top = "Top",
	Bottom = "Bottom",
	Left = "Left",
	Right = "Right",
}

GuiAnimations.In = {}
GuiAnimations.Out = {}
GuiAnimations.Instantly = {}
GuiAnimations.Emphasize = {}

-- Utils

function GuiAnimations.RevertToOriginal(guiObject: GuiObject)
	local position = GuiAnimations._GetOriginalPosition(guiObject)
	local orgTransparencyTable = GuiAnimations._GetOriginalTransparencyTable(guiObject)
	local orgRotation = GuiAnimations._GetOriginalRotation(guiObject)
	local orgSize = GuiAnimations._GetOriginalSize(guiObject)

	guiObject.Position = position

	for prop, val in orgTransparencyTable do
		guiObject[prop] = val
	end

	local origProps = { Position = position, Rotation = orgRotation, Size = orgSize }
	origProps = TableUtil.Reconcile(origProps, orgTransparencyTable)

	TweenService:Create(guiObject, TweenInfo.new(0), origProps):Play()

	-- Revert UIStrokes
	for _, child in ipairs(guiObject:GetChildren()) do
		if child:IsA("UIStroke") then
			local orgTrans = GuiAnimations._GetOriginalUIStrokeTransparency(child)
			TweenService:Create(child, TweenInfo.new(0), { Transparency = orgTrans }):Play()
		end
	end
end

function GuiAnimations.UpdateOriginalPosition(guiObject: GuiObject)
	guiObject:SetAttribute(GuiAnimations._SavedPositionAttName, guiObject.Position)
end

-- In

function GuiAnimations.In.FlyInFromLeft(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetOriginalPosition(guiObject)
	local startPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Left)

	if teleport then
		guiObject.Position = startPos
	end

	guiObject.Visible = true
	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos })
end

function GuiAnimations.In.FlyInFromRight(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetOriginalPosition(guiObject)
	local startPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Right)

	if teleport then
		guiObject.Position = startPos
	end

	guiObject.Visible = true
	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos })
end

function GuiAnimations.In.FlyInFromTop(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetOriginalPosition(guiObject)
	local startPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Top)

	if teleport then
		guiObject.Position = startPos
	end

	guiObject.Visible = true
	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos })
end

function GuiAnimations.In.FlyInFromBottom(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetOriginalPosition(guiObject)
	local startPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Bottom)

	if teleport then
		guiObject.Position = startPos
	end

	guiObject.Visible = true
	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos })
end

-- Out

function GuiAnimations.Out.TeleportOutToLeft(guiObject: GuiObject)
	GuiAnimations._GetOriginalPosition(guiObject)
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Left)
	guiObject.Position = finalPos
	guiObject.Visible = false
end

function GuiAnimations.Out.TeleportOutToRight(guiObject: GuiObject)
	GuiAnimations._GetOriginalPosition(guiObject)
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Right)
	guiObject.Position = finalPos
	guiObject.Visible = false
end

function GuiAnimations.Out.TeleportOutToTop(guiObject: GuiObject)
	GuiAnimations._GetOriginalPosition(guiObject)
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Top)
	guiObject.Position = finalPos
	guiObject.Visible = false
end

function GuiAnimations.Out.TeleportOutToBottom(guiObject: GuiObject)
	GuiAnimations._GetOriginalPosition(guiObject)
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Bottom)
	guiObject.Position = finalPos
	guiObject.Visible = false
end

function GuiAnimations.Out.FlyOutToLeft(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Left)
	local startPos = GuiAnimations._GetOriginalPosition(guiObject)

	if teleport then
		guiObject.Position = startPos
	end

	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos }):andThen(function()
		guiObject.Visible = false
	end)
end

function GuiAnimations.Out.FlyOutToRight(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Right)
	local startPos = GuiAnimations._GetOriginalPosition(guiObject)

	if teleport then
		guiObject.Position = startPos
	end

	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos }):andThen(function()
		guiObject.Visible = false
	end)
end

function GuiAnimations.Out.FlyOutToTop(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Top)
	local startPos = GuiAnimations._GetOriginalPosition(guiObject)

	if teleport then
		guiObject.Position = startPos
	end

	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos }):andThen(function()
		guiObject.Visible = false
	end)
end

function GuiAnimations.Out.FlyOutToBottom(guiObject: GuiObject, tweenInfo: TweenInfo?, teleport: boolean)
	tweenInfo = tweenInfo or GuiAnimations.DefaultTweenInfo
	local finalPos = GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, GuiAnimations._ScreenSides.Bottom)
	local startPos = GuiAnimations._GetOriginalPosition(guiObject)

	if teleport then
		guiObject.Position = startPos
	end

	return GuiAnimations._PlayAnimation(guiObject, tweenInfo, { Position = finalPos }):andThen(function()
		guiObject.Visible = false
	end)
end

function GuiAnimations.In.FadeIn(guiObject: GuiObject, tweenInfo: TweenInfo?, reset: boolean?, recursive: boolean?)
	local originalTransparencyTable = GuiAnimations._GetOriginalTransparencyTable(guiObject)

	if reset then
		-- This ensures Text, Image, and Background transparencies are all reset to 1
		GuiAnimations._ApplyTransparencyTable(guiObject, GuiAnimations._GetInvisibleTransparencyTable(guiObject))
	end

	guiObject.Visible = true

	local promises = {}
	table.insert(promises, GuiAnimations._PlayAnimation(guiObject, tweenInfo, originalTransparencyTable))

	for _, child in ipairs(guiObject:GetChildren()) do
		if child:IsA("UIStroke") then
			local orgStrokeTrans = GuiAnimations._GetOriginalUIStrokeTransparency(child)
			if reset then
				child.Transparency = 1
			end
			table.insert(promises, GuiAnimations._PlayAnimation(child, tweenInfo, { Transparency = orgStrokeTrans }))
		elseif child:IsA("GuiObject") and recursive then
			table.insert(promises, GuiAnimations.In.FadeIn(child, tweenInfo, reset, true))
		end
	end

	return Promise.all(promises)
end

function GuiAnimations.Out.FadeOut(guiObject: GuiObject, tweenInfo: TweenInfo?, reset: boolean?, recursive: boolean?)
	local originalTransparencyTable = GuiAnimations._GetOriginalTransparencyTable(guiObject)
	if reset then
		guiObject.Visible = true
		GuiAnimations._ApplyTransparencyTable(guiObject, originalTransparencyTable)
	end

	local promises = {}

	local mainPromise = GuiAnimations._PlayAnimation(
		guiObject,
		tweenInfo,
		GuiAnimations._GetInvisibleTransparencyTable(guiObject)
	)
		:andThen(function()
			guiObject.Visible = false
		end)
	table.insert(promises, mainPromise)

	for _, child in ipairs(guiObject:GetChildren()) do
		if child:IsA("UIStroke") then
			local orgStrokeTrans = GuiAnimations._GetOriginalUIStrokeTransparency(child)
			if reset then
				child.Transparency = orgStrokeTrans
			end
			table.insert(promises, GuiAnimations._PlayAnimation(child, tweenInfo, { Transparency = 1 }))
		elseif child:IsA("GuiObject") and recursive then
			table.insert(promises, GuiAnimations.Out.FadeOut(child, tweenInfo, reset, true))
		end
	end

	return Promise.all(promises)
end

-- Emphasize
function GuiAnimations.Emphasize.Shake(guiObject: GuiObject, time) end

function GuiAnimations.Emphasize.Grow(guiObject: GuiObject, time: number?)
	time = time or 0.3
	local tweenInfo = TweenInfo.new(time / 2)

	local growAmount = 0.2
	local newSize = UDim2.fromOffset(guiObject.AbsoluteSize.X * growAmount, guiObject.AbsoluteSize.Y * growAmount)

	local originalSize = GuiAnimations._GetOriginalSize(guiObject)

	GuiAnimations.RevertToOriginal(guiObject)

	local tween
	tween = TweenService:Create(guiObject, tweenInfo, { Size = originalSize + newSize })
	tween:Play()
	tween.Completed:Wait()

	tween = TweenService:Create(guiObject, tweenInfo, { Size = originalSize })
	tween:Play()
end

function GuiAnimations.Emphasize.GigglePop(guiObject: GuiObject, reset)
	task.spawn(function()
		local originalSize = GuiAnimations._GetOriginalSize(guiObject)
		local originalRotation = GuiAnimations._GetOriginalRotation(guiObject)

		local originalAbsoluteSize = guiObject.AbsoluteSize
		local function getNewSize(scale)
			scale = scale - 1
			return originalSize + UDim2.fromOffset(originalAbsoluteSize.X * scale, originalAbsoluteSize.Y * scale)
		end

		local time = 0.4

		local angle = 20
		local scale = 1.2

		local tweenInfo1 = TweenInfo.new(time * 7 / 30, Enum.EasingStyle.Sine)
		local tweenInfo2 = TweenInfo.new(time * 13 / 30, Enum.EasingStyle.Sine)
		local tweenInfo3 = TweenInfo.new(time * 13 / 30, Enum.EasingStyle.Sine)
		local tweenInfo4 = TweenInfo.new(time * 20 / 30, Enum.EasingStyle.Sine)

		if reset then
			GuiAnimations.RevertToOriginal(guiObject)
		end

		local tween
		tween = TweenService:Create(guiObject, tweenInfo1, { Size = getNewSize(1.2), Rotation = angle })
		tween:Play()
		tween.Completed:Wait()

		tween = TweenService:Create(guiObject, tweenInfo2, { Size = getNewSize(1 - 0.1), Rotation = -angle / 2 })
		tween:Play()
		tween.Completed:Wait()

		tween = TweenService:Create(guiObject, tweenInfo3, { Size = originalSize, Rotation = angle / 4 })
		tween:Play()
		tween.Completed:Wait()

		tween = TweenService:Create(guiObject, tweenInfo4, { Size = originalSize, Rotation = originalRotation })
		tween:Play()
		tween.Completed:Wait()
	end)
end

function GuiAnimations.Emphasize.Bounce(guiObject: GuiObject, reset)
	task.spawn(function()
		local originalSize = GuiAnimations._GetOriginalSize(guiObject)
		local originalRotation = GuiAnimations._GetOriginalRotation(guiObject)
		local originalPosition = GuiAnimations._GetOriginalPosition(guiObject)

		local originalAbsoluteSize = guiObject.AbsoluteSize
		local function getNewSize(scale)
			scale = scale - 1
			return originalSize + UDim2.fromOffset(originalAbsoluteSize.X * scale, originalAbsoluteSize.Y * scale)
		end

		local time = 0.4

		local angle = 20
		local scale = 1.2

		local tweenInfo1 = TweenInfo.new(0.1, Enum.EasingStyle.Circular)
		local tweenInfo2 = TweenInfo.new(1, Enum.EasingStyle.Elastic)

		if reset then
			GuiAnimations.RevertToOriginal(guiObject)
		end

		local tween
		tween = TweenService:Create(guiObject, tweenInfo1, { Position = originalPosition + UDim2.fromOffset(0, -10) })
		tween:Play()
		tween.Completed:Wait()

		tween = TweenService:Create(guiObject, tweenInfo2, { Position = originalPosition })
		tween:Play()
		tween.Completed:Wait()
	end)
end

-- Private Methods

function GuiAnimations._ApplyTransparencyTable(guiObject: GuiObject, transparencyTable)
	for prop, val in transparencyTable do
		guiObject[prop] = val
	end
end

function GuiAnimations._GetOriginalPosition(guiObject: GuiObject)
	local orgPos = guiObject:GetAttribute(GuiAnimations._SavedPositionAttName)
	if not orgPos then
		orgPos = guiObject.Position
		guiObject:SetAttribute(GuiAnimations._SavedPositionAttName, orgPos)
	end

	return orgPos
end

function GuiAnimations._GetOriginalUIStrokeTransparency(uiStroke: UIStroke)
	local orgTrans = uiStroke:GetAttribute(GuiAnimations._SavedUIStrokeTransparencyAttName)
	if not orgTrans then
		orgTrans = uiStroke.Transparency
		uiStroke:SetAttribute(GuiAnimations._SavedUIStrokeTransparencyAttName, orgTrans)
	end
	return orgTrans
end

function GuiAnimations._GetOriginalTransparencyTable(guiObject: GuiObject)
	local orgBackgroundTransparency = guiObject:GetAttribute(GuiAnimations._SavedBackgroundTransparencyAttName)
	if not orgBackgroundTransparency then
		orgBackgroundTransparency = guiObject.BackgroundTransparency
		guiObject:SetAttribute(GuiAnimations._SavedBackgroundTransparencyAttName, orgBackgroundTransparency)
	end

	local orgTextTransparency, orgTextStrokeTransparency
	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
		orgTextTransparency = guiObject:GetAttribute(GuiAnimations._SavedTextTransparencyAttName)
		if not orgTextTransparency then
			orgTextTransparency = guiObject.TextTransparency
			guiObject:SetAttribute(GuiAnimations._SavedTextTransparencyAttName, orgTextTransparency)
		end

		orgTextStrokeTransparency = guiObject:GetAttribute(GuiAnimations._SavedTextStrokeTransparencyAttName)
		if not orgTextStrokeTransparency then
			orgTextStrokeTransparency = guiObject.TextStrokeTransparency
			guiObject:SetAttribute(GuiAnimations._SavedTextStrokeTransparencyAttName, orgTextStrokeTransparency)
		end
	end

	local orgImageTransparency
	if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
		orgImageTransparency = guiObject:GetAttribute(GuiAnimations._SavedImageTransparencyAttName)
		if not orgImageTransparency then
			orgImageTransparency = guiObject.ImageTransparency
			guiObject:SetAttribute(GuiAnimations._SavedImageTransparencyAttName, orgImageTransparency)
		end
	end

	return {
		BackgroundTransparency = orgBackgroundTransparency,
		TextTransparency = orgTextTransparency,
		TextStrokeTransparency = orgTextStrokeTransparency,
		ImageTransparency = orgImageTransparency,
	}
end

function GuiAnimations._GetOriginalRotation(guiObject: GuiObject)
	local orgRoation = guiObject:GetAttribute(GuiAnimations._SavedRotationAttName)
	if not orgRoation then
		orgRoation = guiObject.Rotation
		guiObject:SetAttribute(GuiAnimations._SavedRotationAttName, orgRoation)
	end

	return orgRoation
end

function GuiAnimations._GetInvisibleTransparencyTable(guiObject: GuiObject)
	local transparencyTable = GuiAnimations._GetOriginalTransparencyTable(guiObject)

	for key, _ in transparencyTable do
		transparencyTable[key] = 1
	end

	return transparencyTable
end

function GuiAnimations._GetOriginalSize(guiObject: GuiObject)
	local orgSize = guiObject:GetAttribute(GuiAnimations._SavedSizeAttName)
	if not orgSize then
		orgSize = guiObject.Size
		guiObject:SetAttribute(GuiAnimations._SavedSizeAttName, orgSize)
	end

	return orgSize
end

function GuiAnimations._PlayAnimation(guiObject: GuiObject, tweenInfo, propertyTable)
	local tween = TweenService:Create(guiObject, tweenInfo, propertyTable)
	tween:Play()

	local promiseTrove = Trove.new()
	local promise
	promise = Promise.new(function(resolve)
		promiseTrove:Add(tween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				promiseTrove:Clean()
				resolve()
			else
				promiseTrove:Clean()
				promise:cancel()
			end
		end))

		promiseTrove:Add(RunService.RenderStepped:Connect(function()
			if tween.PlaybackState == Enum.PlaybackState.Cancelled then
				promiseTrove:Clean()
				promise:cancel()
			end
		end))
	end)

	return promise
end

function GuiAnimations._GetGuiPositionOnSideOfScreen(guiObject, screenSide)
	if screenSide == GuiAnimations._ScreenSides.Top then
		return GuiUtils.AbsoluteToOffsetPosition(
			guiObject,
			Vector2.new(guiObject.AbsolutePosition.X, -guiObject.AbsoluteSize.Y)
		)
	elseif screenSide == GuiAnimations._ScreenSides.Bottom then
		return GuiUtils.AbsoluteToOffsetPosition(
			guiObject,
			Vector2.new(guiObject.AbsolutePosition.X, guiObject.AbsolutePosition.Y + guiObject.AbsoluteSize.Y)
		)
	elseif screenSide == GuiAnimations._ScreenSides.Left then
		return GuiUtils.AbsoluteToOffsetPosition(
			guiObject,
			Vector2.new(-guiObject.AbsoluteSize.X, guiObject.AbsolutePosition.Y)
		)
	elseif screenSide == GuiAnimations._ScreenSides.Right then
		return GuiUtils.AbsoluteToOffsetPosition(
			guiObject,
			Vector2.new(GuiUtils.GetGuiBaseSize(guiObject).X, guiObject.AbsolutePosition.Y)
		)
	end
end

return GuiAnimations
