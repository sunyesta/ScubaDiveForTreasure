local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Assuming these packages exist in your project structure
local Trove = require(ReplicatedStorage.Packages.Trove)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local DefaultValue = require(ReplicatedStorage.NonWallyPackages.DefaultValue)
local Promise = require(ReplicatedStorage.Packages.Promise)

local GuiProgressBar = {}
GuiProgressBar.__index = GuiProgressBar

GuiProgressBar.Directions = {
	Horizontal = "Horizontal",
	Vertical = "Vertical",
}

export type GuiProgressBar = {
	MaxValue: any, -- Property object
	Value: any, -- Property object
	TweenInfo: TweenInfo,
	Destroy: (self: GuiProgressBar) -> (),
	Wrap: (self: GuiProgressBar) -> any, -- Returns Promise
	SetValueInstant: (self: GuiProgressBar, value: number) -> (),
}

function GuiProgressBar.new(bar: GuiObject, direction: string?, initialValue: number?, maxValue: number?)
	local self = setmetatable({}, GuiProgressBar)

	-- private
	self._Trove = Trove.new()
	self._Bar = bar
	self._Direction = direction or GuiProgressBar.Directions.Horizontal
	self._CurrentTween = nil :: Tween?
	self._SkipTween = false

	-- public
	self.MaxValue = Property.new(DefaultValue(maxValue, 1))
	self.Value = Property.new(DefaultValue(initialValue, 0.5))
	self.TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	-- Setup Layout Logic (Size-based)
	-- This approach is more robust than position-sliding as it doesn't strictly require ClipsDescendants
	if self._Direction == GuiProgressBar.Directions.Horizontal then
		-- Anchored Left, grows Right
		bar.AnchorPoint = Vector2.new(0, 0)
		bar.Position = UDim2.fromScale(0, 0)
		bar.Size = UDim2.fromScale(0, 1) -- Start empty width, full height
	else
		-- Anchored Bottom, grows Up
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.Size = UDim2.fromScale(1, 0) -- Start full width, empty height
	end

	local function updateValue(teleport: boolean?)
		local max = self.MaxValue:Get()
		if max == 0 then
			max = 1
		end -- Prevent division by zero

		local percent = self.Value:Get() / max
		percent = math.clamp(percent, 0, 1)

		local targetSize = self:_GetSizeFromPercent(percent)

		-- Cancel existing tween if it exists to prevent fighting
		if self._CurrentTween then
			self._CurrentTween:Cancel()
			self._CurrentTween = nil
		end

		if teleport then
			bar.Size = targetSize
		else
			local tween = TweenService:Create(bar, self.TweenInfo, { Size = targetSize })
			self._CurrentTween = tween
			tween:Play()
		end
	end

	-- Connect signals
	-- Using Trove:Connect automatically cleans up the connection when Trove is cleaned
	self._Trove:Connect(self.MaxValue.Changed, function()
		updateValue(false)
	end)

	self._Trove:Connect(self.Value.Changed, function()
		updateValue(self._SkipTween)
	end)

	-- Clean up tween on destroy
	self._Trove:Add(function()
		if self._CurrentTween then
			self._CurrentTween:Cancel()
		end
	end)

	-- Initial render
	updateValue(true)

	return self
end

function GuiProgressBar:Destroy()
	self._Trove:Clean()
end

function GuiProgressBar:SetValueInstant(value: number)
	self._SkipTween = true
	self.Value:Set(value)
	self._SkipTween = false
end

function GuiProgressBar:_GetSizeFromPercent(percent: number): UDim2
	if self._Direction == GuiProgressBar.Directions.Horizontal then
		return UDim2.fromScale(percent, 1)
	else
		return UDim2.fromScale(1, percent)
	end
end

-- Useful for "Level Up" bars that fill to 100% then reset to 0%
function GuiProgressBar:Wrap()
	return Promise.try(function()
		-- 1. Tween to 100%
		if self._CurrentTween then
			self._CurrentTween:Cancel()
		end

		local tween = TweenService:Create(self._Bar, self.TweenInfo, { Size = self:_GetSizeFromPercent(1) })
		self._CurrentTween = tween
		tween:Play()
		tween.Completed:Wait()

		-- 2. Snap to 0% (Visual reset)
		self._Bar.Size = self:_GetSizeFromPercent(0)
		self._CurrentTween = nil
	end)
end

return GuiProgressBar
