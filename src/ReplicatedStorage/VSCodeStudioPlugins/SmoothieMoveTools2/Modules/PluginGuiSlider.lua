local UserInputService = game:GetService("UserInputService")

local Property = require(script.Parent.PropertyLite)
local Trove = require(script.Parent.Trove)
local Signal = require(script.Parent.Signal)

-- Simple linear interpolation
local function lerp(start: number, goal: number, alpha: number): number
	return start + (goal - start) * alpha
end

local GuiSlider = {}
GuiSlider.__index = GuiSlider

GuiSlider.Directions = {
	Vertical = "Vertical",
	Horizontal = "Horizontal",
}

-- Strict Luau typing for our parameters
export type SliderParams = {
	Bar: GuiButton,
	Handle: GuiButton,
	Direction: string?,
	IntOnly: boolean?,
	MinValue: number?,
	MaxValue: number?,
	DefaultValue: number?,
}

function GuiSlider.new(gui: GuiObject | DockWidgetPluginGui | ScreenGui, params: SliderParams)
	local self = setmetatable({}, GuiSlider)

	-- Ensure safety and correctly identify instances
	assert(typeof(params.Bar) == "Instance" and params.Bar:IsA("GuiButton"), "Bar must be a GuiButton")
	assert(typeof(params.Handle) == "Instance" and params.Handle:IsA("GuiButton"), "Handle must be a GuiButton")
	assert(params.Handle.Parent == params.Bar, "Handle's parent must be the Bar")

	self._Trove = Trove.new()

	-- Set default values with fallbacks
	self._MinValue = if params.MinValue ~= nil then params.MinValue else 0
	self._MaxValue = if params.MaxValue ~= nil then params.MaxValue else 1
	self._IntOnly = if params.IntOnly ~= nil then params.IntOnly else false
	self._Direction = params.Direction or GuiSlider.Directions.Horizontal
	local defaultValue = if params.DefaultValue ~= nil then params.DefaultValue else self._MinValue

	-- Init objects
	self.Bar = params.Bar
	self.Handle = params.Handle
	self.Value = self._Trove:Add(Property.new(defaultValue))
	self.Dragged = self._Trove:Add(Signal.new())

	-- Find a safe target for input tracking.
	-- PluginGuis throw a "RobloxScript capability" error if we connect to InputChanged directly.
	local dragTarget: any = gui
	if typeof(gui) == "Instance" and not gui:IsA("GuiObject") then
		-- Crawl up from the Bar to find the highest-level GuiObject (usually a background Frame)
		local current = params.Bar
		while current.Parent and current.Parent:IsA("GuiObject") do
			current = current.Parent
		end
		dragTarget = current
	end

	-- Configure handle centering
	self.Handle.AnchorPoint = Vector2.new(0.5, 0.5)

	local function updateHandlePosition()
		-- math.max prevents division by zero if MinValue and MaxValue are the same
		local range = math.max(self._MaxValue - self._MinValue, 0.0001)
		local position = math.clamp((self.Value:Get() - self._MinValue) / range, 0, 1)

		-- UX Improvement: Using Scale (0.5) ensures it stays centered even if the plugin window is resized!
		if self._Direction == GuiSlider.Directions.Horizontal then
			self.Handle.Position = UDim2.new(position, 0, 0.5, 0)
		elseif self._Direction == GuiSlider.Directions.Vertical then
			self.Handle.Position = UDim2.new(0.5, 0, position, 0)
		else
			error("Unknown GuiSlider direction: " .. tostring(self._Direction))
		end
	end

	self._Trove:Add(self.Value:Observe(updateHandlePosition))
	updateHandlePosition() -- Run once to set initial position

	-- Input Handling
	local dragTrove = self._Trove:Extend()

	local function updateValueFromInput(inputPosition: Vector3)
		local relativePosition = (Vector2.new(inputPosition.X, inputPosition.Y) - self.Bar.AbsolutePosition)
			/ self.Bar.AbsoluteSize

		local alpha = if self._Direction == GuiSlider.Directions.Horizontal
			then relativePosition.X
			else relativePosition.Y
		local newValue = lerp(self._MinValue, self._MaxValue, math.clamp(alpha, 0, 1))

		if self._IntOnly then
			newValue = math.round(newValue)
		end

		self.Value:Set(newValue)
		self.Dragged:Fire()
	end

	local function onInputBegan(input: InputObject)
		-- Only trigger if we clicked with the left mouse button
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragTrove:Clean() -- Clean any stuck connections just in case

			-- Instantly update the slider to exactly where we clicked
			updateValueFromInput(input.Position)

			-- We use the `dragTarget` element to safely track movement and bypass the capability error.
			dragTrove:Add(dragTarget.InputChanged:Connect(function(moveInput: InputObject)
				if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
					updateValueFromInput(moveInput.Position)
				end
			end))

			-- The most reliable way to detect a release in Roblox UI is to track the
			-- exact InputObject that initiated the click! It updates its state to 'End'
			-- when you lift your mouse, regardless of where your cursor is.
			dragTrove:Add(input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragTrove:Clean() -- Stop dragging
				end
			end))
		end
	end

	self._Trove:Add(self.Bar.InputBegan:Connect(onInputBegan))
	self._Trove:Add(self.Handle.InputBegan:Connect(onInputBegan))

	return self
end

function GuiSlider:Destroy()
	self._Trove:Clean()
end

return GuiSlider
