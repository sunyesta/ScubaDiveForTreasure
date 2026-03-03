local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService") -- Added ChangeHistoryService

local Props = require(script.Parent.Props)
local Enums = require(script.Parent.Enums)
local PluginMouse = require(script.Parent.Modules.PluginMouse)
local PluginGuiSlider = require(script.Parent.Modules.PluginGuiSlider)
local ColorBehavior = require(script.Parent.ColorBehavior)

local Widget = {}

-- Track if the user is currently dragging a color slider
local isColorDragging = false

-- Theme Constants
local THEME = {
	Background = Color3.fromRGB(17, 24, 39), -- gray-950
	SectionBg = Color3.fromRGB(31, 41, 55), -- gray-800
	Text = Color3.fromRGB(243, 244, 246), -- gray-100
	TextMuted = Color3.fromRGB(156, 163, 175), -- gray-400
	Primary = Color3.fromRGB(37, 99, 235), -- blue-600
	Hover = Color3.fromRGB(55, 65, 81), -- gray-700
	Border = Color3.fromRGB(75, 85, 99), -- gray-600
}

-- UI Building Utilities
local function createFrame(parent, config)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = THEME.Background
	frame.BorderSizePixel = 0
	frame.Parent = parent
	for k, v in pairs(config or {}) do
		frame[k] = v
	end
	return frame
end

local function createText(parent, config)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextColor3 = THEME.Text
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 14
	text.Parent = parent
	for k, v in pairs(config or {}) do
		text[k] = v
	end
	return text
end

local function createRow(parent, labelText)
	local row = createFrame(parent, {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	})

	local label = createText(row, {
		Text = string.upper(labelText),
		Size = UDim2.new(0, 80, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
	})

	local container = createFrame(row, {
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.new(0, 80, 0, 0),
		BackgroundTransparency = 1,
	})

	return container, row
end

-- Updated UI Builder for Icon-based Inputs with Custom Size parameter
local function createIconInputBox(parent, iconId, property, trove, customSize)
	local container = createFrame(parent, {
		Size = customSize or UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = THEME.SectionBg,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = container

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.Position = UDim2.new(0, 8, 0.5, -8)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = THEME.TextMuted
	icon.Parent = container

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -32, 1, 0)
	textBox.Position = UDim2.new(0, 32, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.TextColor3 = THEME.Text
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 14
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.Parent = container

	textBox.FocusLost:Connect(function()
		local num = tonumber(textBox.Text)
		if num then
			property:Set(num)
		else
			textBox.Text = tostring(property:Get())
		end
	end)

	-- Sync text back when property updates externally
	trove:Add(property:Observe(function(val)
		if val ~= nil and not textBox:IsFocused() then
			textBox.Text = tostring(val)
		end
	end))

	return container
end

-- New UI Builder for Quick Preset Buttons
local function createQuickButton(parent, labelText, value, property)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 36, 1, 0)
	btn.BackgroundColor3 = THEME.SectionBg
	btn.Text = labelText
	btn.TextColor3 = THEME.TextMuted
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 12
	btn.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.Parent = parent

	btn.MouseButton1Click:Connect(function()
		property:Set(value)
	end)

	return btn
end

local function createSegmentedControl(parent, options, property, trove)
	local container = createFrame(parent, {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = THEME.SectionBg,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local buttons = {}
	local buttonWidth = 1 / #options

	for i, opt in ipairs(options) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(buttonWidth, 0, 1, 0)
		btn.Text = opt.Label
		btn.Font = Enum.Font.GothamSemibold
		btn.TextSize = 12
		btn.BackgroundColor3 = THEME.Primary
		btn.AutoButtonColor = false

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		btn.Parent = container
		buttons[opt.Value] = btn

		btn.MouseButton1Click:Connect(function()
			property:Set(opt.Value)
		end)
	end

	-- Sync from Property
	trove:Add(property:Observe(function(newValue)
		for val, btn in pairs(buttons) do
			if val == newValue then
				btn.BackgroundTransparency = 0
				btn.TextColor3 = Color3.new(1, 1, 1)
			else
				btn.BackgroundTransparency = 1
				btn.TextColor3 = THEME.TextMuted
			end
		end
	end))
end

local function createToggle(parent, labelText, property, trove)
	local container = createFrame(parent, {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	})

	local toggleBg = createFrame(container, {
		Size = UDim2.new(0, 40, 0, 24),
		Position = UDim2.new(0, 0, 0.5, -12),
		BackgroundColor3 = THEME.SectionBg,
	})
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = toggleBg

	local knob = createFrame(toggleBg, {
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(0, 4, 0.5, -8),
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	createText(container, {
		Text = labelText,
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 50, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
	})

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = container

	btn.MouseButton1Click:Connect(function()
		property:Set(not property:Get())
	end)

	-- Sync
	trove:Add(property:Observe(function(isToggled)
		toggleBg.BackgroundColor3 = isToggled and THEME.Primary or THEME.SectionBg
		-- Animate knob position
		knob.Position = isToggled and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
	end))
end

local function createScrubInput(parent, property, min, max, step, trove, pluginGui)
	local container = createFrame(parent, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = THEME.SectionBg })
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = container

	local btnMinus = Instance.new("TextButton")
	btnMinus.Size = UDim2.new(0, 30, 1, 0)
	btnMinus.BackgroundTransparency = 1
	btnMinus.Text = "<"
	btnMinus.TextColor3 = THEME.TextMuted
	btnMinus.Font = Enum.Font.GothamBold
	btnMinus.Parent = container

	local btnPlus = Instance.new("TextButton")
	btnPlus.Size = UDim2.new(0, 30, 1, 0)
	btnPlus.Position = UDim2.new(1, -30, 0, 0)
	btnPlus.BackgroundTransparency = 1
	btnPlus.Text = ">"
	btnPlus.TextColor3 = THEME.TextMuted
	btnPlus.Font = Enum.Font.GothamBold
	btnPlus.Parent = container

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -60, 1, 0)
	textBox.Position = UDim2.new(0, 30, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.TextColor3 = THEME.Text
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 14
	textBox.Parent = container

	local function updateValue(delta)
		local current = property:Get() or 0
		local newVal = math.clamp(current + delta, min, max)
		local inv = 1 / step
		newVal = math.round(newVal * inv) / inv
		property:Set(newVal)
	end

	btnMinus.MouseButton1Click:Connect(function()
		updateValue(-step)
	end)
	btnPlus.MouseButton1Click:Connect(function()
		updateValue(step)
	end)

	textBox.FocusLost:Connect(function()
		local num = tonumber(textBox.Text)
		if num then
			local newVal = math.clamp(num, min, max)
			local inv = 1 / step
			newVal = math.round(newVal * inv) / inv
			property:Set(newVal)
		else
			textBox.Text = tostring(property:Get())
		end
	end)

	-- Dragging Logic
	local dragging = false
	local startX, startVal = 0, 0
	local dragConn = nil

	-- Cleanup just in case widget closes mid-drag
	trove:Add(function()
		if dragConn then
			dragConn:Disconnect()
			dragConn = nil
		end
	end)

	textBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			startX = pluginGui:GetRelativeMousePosition().X
			startVal = property:Get() or 0

			if dragConn then
				dragConn:Disconnect()
			end
			dragConn = RunService.Heartbeat:Connect(function()
				if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					dragging = false
					if dragConn then
						dragConn:Disconnect()
						dragConn = nil
						-- Create a waypoint when we finish dragging the scrubber!
						ChangeHistoryService:SetWaypoint("Change Value")
					end
					return
				end

				local currentX = pluginGui:GetRelativeMousePosition().X
				local deltaX = currentX - startX
				local sensitivity = 0.5
				local newVal = math.clamp(startVal + (deltaX * sensitivity * step), min, max)
				local inv = 1 / step
				newVal = math.round(newVal * inv) / inv
				property:Set(newVal)
			end)
		end
	end)

	trove:Add(property:Observe(function(val)
		if val then
			textBox.Text = tostring(val)
		end
	end))
end

local function createHexRow(parent, labelText, property, trove)
	local container = createFrame(parent, { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 })

	createText(container, {
		Text = labelText,
		Size = UDim2.new(0, 50, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 12,
	})

	local textBoxBg = createFrame(container, {
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 50, 0, 0),
		BackgroundColor3 = THEME.SectionBg,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = textBoxBg

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -16, 1, 0)
	textBox.Position = UDim2.new(0, 8, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.TextColor3 = THEME.Text
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 12
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.Parent = textBoxBg

	textBox.FocusLost:Connect(function()
		local text = textBox.Text
		-- pcall handles invalid strings safely without throwing an error in the console
		local success, newColor = pcall(function()
			return Color3.fromHex(text)
		end)

		if success and newColor then
			property:Set(newColor)
			ChangeHistoryService:SetWaypoint("Change Hex Color") -- I also added it here for completeness!
		else
			-- Reset text to current color if input was invalid
			local color = property:Get()
			if color then
				textBox.Text = "#" .. color:ToHex():upper()
			end
		end
	end)

	-- Sync text back when color updates externally (unless currently typing)
	trove:Add(property:Observe(function(color)
		if color and not textBox:IsFocused() then
			textBox.Text = "#" .. color:ToHex():upper()
		end
	end))
end

local function createColorSlider(parent, labelText, property, channel, trove, pluginGui)
	local container = createFrame(parent, { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 })

	createText(container, {
		Text = labelText,
		Size = UDim2.new(0, 50, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 12,
	})
	local valueText = createText(container, {
		Text = "0",
		Size = UDim2.new(0, 30, 0, 14),
		Position = UDim2.new(1, -30, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.Code,
	})

	local track = Instance.new("ImageButton")
	track.Size = UDim2.new(1, 0, 0, 12)
	track.Position = UDim2.new(0, 0, 0, 18)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.ImageTransparency = 1
	track.AutoButtonColor = false
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	local gradient = Instance.new("UIGradient")
	gradient.Parent = track

	local knob = Instance.new("ImageButton")
	knob.Size = UDim2.new(0, 4, 1, 4)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.ImageTransparency = 1
	knob.AutoButtonColor = false
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Parent = track

	-- Connect dragging hooks for Undo functionality using Heartbeat polling
	local function markDragging(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not isColorDragging then
			isColorDragging = true

			local dragConn
			dragConn = RunService.Heartbeat:Connect(function()
				if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					isColorDragging = false
					ChangeHistoryService:SetWaypoint("Change Tool Color")

					if dragConn then
						dragConn:Disconnect()
						dragConn = nil
					end
				end
			end)
		end
	end
	track.InputBegan:Connect(markDragging)
	knob.InputBegan:Connect(markDragging)

	local slider = trove:Add(PluginGuiSlider.new(pluginGui, {
		Bar = track,
		Handle = knob,
		Direction = PluginGuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	trove:Add(slider.Value:Observe(function(val)
		if not val then
			return
		end
		local currentColor = property:Get() or Color3.new()
		local r, g, b = currentColor.R, currentColor.G, currentColor.B

		if channel == "R" then
			r = val
		elseif channel == "G" then
			g = val
		elseif channel == "B" then
			b = val
		end

		property:Set(Color3.new(r, g, b))
	end))

	trove:Add(property:Observe(function(color)
		if not color then
			return
		end
		local val = channel == "R" and color.R or channel == "G" and color.G or color.B
		valueText.Text = tostring(math.floor(val * 255))

		if math.abs(slider.Value:Get() - val) > 0.001 then
			slider.Value:Set(val)
		end

		if channel == "R" then
			gradient.Color = ColorSequence.new(Color3.new(0, color.G, color.B), Color3.new(1, color.G, color.B))
		elseif channel == "G" then
			gradient.Color = ColorSequence.new(Color3.new(color.R, 0, color.B), Color3.new(color.R, 1, color.B))
		elseif channel == "B" then
			gradient.Color = ColorSequence.new(Color3.new(color.R, color.G, 0), Color3.new(color.R, color.G, 1))
		end
	end))
end

local function createHSVSlider(parent, labelText, property, channel, trove, pluginGui)
	local container = createFrame(parent, { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 })

	createText(container, {
		Text = labelText,
		Size = UDim2.new(0, 80, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 12,
	})
	local valueText = createText(container, {
		Text = "0",
		Size = UDim2.new(0, 30, 0, 14),
		Position = UDim2.new(1, -30, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.Code,
	})

	local track = Instance.new("ImageButton")
	track.Size = UDim2.new(1, 0, 0, 12)
	track.Position = UDim2.new(0, 0, 0, 18)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.ImageTransparency = 1
	track.AutoButtonColor = false
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	local gradient = Instance.new("UIGradient")
	gradient.Parent = track

	if channel == "H" then
		local keypoints = {}
		for i = 0, 6 do
			table.insert(keypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
		end
		gradient.Color = ColorSequence.new(keypoints)
	end

	local knob = Instance.new("ImageButton")
	knob.Size = UDim2.new(0, 4, 1, 4)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.ImageTransparency = 1
	knob.AutoButtonColor = false
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Parent = track

	-- Connect dragging hooks for Undo functionality using Heartbeat polling
	local function markDragging(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not isColorDragging then
			isColorDragging = true

			local dragConn
			dragConn = RunService.Heartbeat:Connect(function()
				if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					isColorDragging = false
					ChangeHistoryService:SetWaypoint("Change Tool Color")

					if dragConn then
						dragConn:Disconnect()
						dragConn = nil
					end
				end
			end)
		end
	end
	track.InputBegan:Connect(markDragging)
	knob.InputBegan:Connect(markDragging)

	local slider = trove:Add(PluginGuiSlider.new(pluginGui, {
		Bar = track,
		Handle = knob,
		Direction = PluginGuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	trove:Add(slider.Value:Observe(function(val)
		if not val then
			return
		end
		local currentColor = property:Get() or Color3.new()
		local h, s, v = currentColor:ToHSV()

		if channel == "H" then
			h = val
		elseif channel == "S" then
			s = val
		elseif channel == "V" then
			v = val
		end

		property:Set(Color3.fromHSV(h, s, v))
	end))

	trove:Add(property:Observe(function(color)
		if not color then
			return
		end
		local h, s, v = color:ToHSV()
		local val = channel == "H" and h or channel == "S" and s or v
		local maxDisplay = channel == "H" and 360 or 100

		valueText.Text = tostring(math.floor(val * maxDisplay))

		if math.abs(slider.Value:Get() - val) > 0.001 then
			slider.Value:Set(val)
		end

		if channel == "S" then
			gradient.Color = ColorSequence.new(Color3.fromHSV(h, 0, v), Color3.fromHSV(h, 1, v))
		elseif channel == "V" then
			gradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
		end
	end))
end

function Widget.Init(plugin, trove)
	local pluginMouse = PluginMouse.new()
	trove:Add(pluginMouse)

	-- 1. Create the Dock Widget
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Left,
		true, -- Initially Enabled
		false, -- Override Previous Enabled State
		320, -- Default Width
		550, -- Default Height
		280, -- Minimum Width
		400 -- Minimum Height
	)

	local pluginGui = plugin:CreateDockWidgetPluginGui("SmoothieMoveTools", widgetInfo)
	pluginGui.Title = "Smoothie Move Tools"
	trove:Add(pluginGui)

	-- 2. Main Container Setup
	local mainScroll = Instance.new("ScrollingFrame")
	mainScroll.Size = UDim2.new(1, 0, 1, 0)
	mainScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	mainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	mainScroll.BackgroundColor3 = THEME.Background
	mainScroll.BorderSizePixel = 0
	mainScroll.ScrollBarThickness = 4
	mainScroll.Parent = pluginGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 16)
	listLayout.Parent = mainScroll

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = mainScroll

	-- 3. Transform Section
	local transformSection = createFrame(mainScroll, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})
	local tLayout = Instance.new("UIListLayout")
	tLayout.Padding = UDim.new(0, 8)
	tLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tLayout.Parent = transformSection

	createText(transformSection, {
		Text = "Transform",
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
	})

	createText(transformSection, {
		Text = "Use Blender controls for moving and rotating",
		Size = UDim2.new(1, 0, 0, 30),
		TextWrapped = true,
		TextColor3 = THEME.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.Gotham,
	})

	-- Stacked Movement Settings Section with Quick Presets
	local movementSettingsContainer = createFrame(transformSection, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	local moveLayout = Instance.new("UIListLayout")
	moveLayout.FillDirection = Enum.FillDirection.Vertical
	moveLayout.Padding = UDim.new(0, 8)
	moveLayout.Parent = movementSettingsContainer

	-- Row 1: Move Studs Increment
	local moveRow = createFrame(movementSettingsContainer, {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	})
	local moveRowLayout = Instance.new("UIListLayout")
	moveRowLayout.FillDirection = Enum.FillDirection.Horizontal
	moveRowLayout.Padding = UDim.new(0, 8)
	moveRowLayout.Parent = moveRow

	-- Input Box dynamically takes up the remaining width (100% minus 132px for the 3 buttons + padding)
	createIconInputBox(moveRow, "rbxassetid://5172066892", Props.MoveStudsIncrement, trove, UDim2.new(1, -132, 1, 0))
	createQuickButton(moveRow, "1", 1, Props.MoveStudsIncrement)
	createQuickButton(moveRow, "0.5", 0.5, Props.MoveStudsIncrement)
	createQuickButton(moveRow, "0.1", 0.1, Props.MoveStudsIncrement)

	-- Row 2: Rotation Degree Increment
	local rotRow = createFrame(movementSettingsContainer, {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	})
	local rotRowLayout = Instance.new("UIListLayout")
	rotRowLayout.FillDirection = Enum.FillDirection.Horizontal
	rotRowLayout.Padding = UDim.new(0, 8)
	rotRowLayout.Parent = rotRow

	createIconInputBox(
		rotRow,
		"rbxassetid://86084882582277",
		Props.RotationDegIncrement,
		trove,
		UDim2.new(1, -132, 1, 0)
	)
	createQuickButton(rotRow, "1°", 1, Props.RotationDegIncrement)
	createQuickButton(rotRow, "10°", 10, Props.RotationDegIncrement)
	createQuickButton(rotRow, "45°", 45, Props.RotationDegIncrement)

	-- Margin between move/rotate rows and tools row
	createFrame(transformSection, {
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundTransparency = 1,
	})

	local toolsRow = createRow(transformSection, "Tools")
	createSegmentedControl(toolsRow, {
		{ Label = "Select", Value = Enums.Tools.Select },
		{ Label = "Scale", Value = Enums.Tools.Scale },
	}, Props.Tool, trove)

	local axisRow = createRow(transformSection, "Axis")

	createSegmentedControl(axisRow, {
		{ Label = "Global", Value = Enums.Axis.Global },
		{ Label = "Local", Value = Enums.Axis.Local },
		{ Label = "View", Value = Enums.Axis.View },
	}, Props.Axis, trove)

	local originRow = createRow(transformSection, "Origin")
	createSegmentedControl(originRow, {
		{ Label = "Center", Value = Enums.Origin.Center },
		{ Label = "Pivot", Value = Enums.Origin.Pivot },
	}, Props.Origin, trove)

	-- NEW: Snapping Group Card
	local snappingCard = createFrame(transformSection, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Background,
		BorderColor3 = THEME.Border,
		BorderSizePixel = 1,
	})

	local snapPadding = Instance.new("UIPadding")
	snapPadding.PaddingTop = UDim.new(0, 8)
	snapPadding.PaddingBottom = UDim.new(0, 8)
	snapPadding.PaddingLeft = UDim.new(0, 8)
	snapPadding.PaddingRight = UDim.new(0, 8)
	snapPadding.Parent = snappingCard

	local snapCorner = Instance.new("UICorner")
	snapCorner.CornerRadius = UDim.new(0, 8)
	snapCorner.Parent = snappingCard

	local snapLayout = Instance.new("UIListLayout")
	snapLayout.Padding = UDim.new(0, 8)
	snapLayout.SortOrder = Enum.SortOrder.LayoutOrder
	snapLayout.Parent = snappingCard

	createText(snappingCard, {
		Text = "SNAPPING",
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
	})

	-- We parent these directly to snappingCard now instead of transformSection
	local useSnappingContainer, useSnappingRow = createRow(snappingCard, "Enabled")
	createToggle(useSnappingContainer, "Use Snapping", Props.UseSnapping, trove)

	local snapModeContainer, snapModeRow = createRow(snappingCard, "Type")
	createSegmentedControl(snapModeContainer, {
		{ Label = "Grid", Value = Enums.SnappingMode.Grid },
		{ Label = "Surface", Value = Enums.SnappingMode.Surface },
	}, Props.SnappingMode, trove)

	local alignContainer, alignRow = createRow(snappingCard, "Align")
	createToggle(alignContainer, "Match rotation to surface", Props.MatchRotationToSurface, trove)

	local gridRowContainer, gridRow = createRow(snappingCard, "Grid Size")
	createScrubInput(gridRowContainer, Props.GridSize, 0.1, 100, 0.1, trove, pluginGui)

	trove:Add(Props.SnappingMode:Observe(function(snapModeValue)
		alignRow.Visible = (snapModeValue == Enums.SnappingMode.Surface)
		gridRow.Visible = (snapModeValue == Enums.SnappingMode.Grid)
	end))

	-- 4. Coloring Section
	local colorSection = createFrame(mainScroll, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	})
	local cLayout = Instance.new("UIListLayout")
	cLayout.Padding = UDim.new(0, 12)
	cLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cLayout.Parent = colorSection

	-- Margin
	createFrame(colorSection, {
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundTransparency = 1,
	})

	-- Coloring Header
	local coloringHeader = createFrame(colorSection, {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})

	createText(coloringHeader, {
		Text = "Coloring",
		Size = UDim2.new(1, -60, 1, 0), -- Updated from -30 to -60 to make room for the new button
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
	})

	local function createSwatch(parent)
		local swatch = createFrame(parent, {
			Size = UDim2.new(0, 24, 0, 24),
			Position = UDim2.new(1, -24, 0, 0), -- Position to the far right edge
			BackgroundColor3 = Color3.new(1, 1, 1),
		})
		local corn = Instance.new("UICorner")
		corn.CornerRadius = UDim.new(0, 4)
		corn.Parent = swatch

		local stroke = Instance.new("UIStroke")
		stroke.Color = THEME.Border
		stroke.Thickness = 1
		stroke.Parent = swatch
		return swatch
	end

	local colorSwatch = createSwatch(coloringHeader)

	-- NEW: Eyedropper Button next to Swatch
	local eyedropperBtn = Instance.new("ImageButton")
	eyedropperBtn.Size = UDim2.new(0, 24, 0, 24)
	eyedropperBtn.Position = UDim2.new(1, -52, 0, 0) -- 24px swatch width + 4px margin = 28px left from the swatch
	eyedropperBtn.BackgroundTransparency = 1
	eyedropperBtn.Image = "rbxassetid://126362121736567"
	eyedropperBtn.ImageColor3 = THEME.TextMuted
	eyedropperBtn.Parent = coloringHeader

	-- Hover effect for the new button (optional nice touch)
	eyedropperBtn.MouseEnter:Connect(function()
		eyedropperBtn.ImageColor3 = THEME.Text
	end)
	eyedropperBtn.MouseLeave:Connect(function()
		eyedropperBtn.ImageColor3 = THEME.TextMuted
	end)

	-- Trigger Eyedropper behavior when clicked
	eyedropperBtn.MouseButton1Click:Connect(function()
		ColorBehavior.StartEyedropperTool(plugin)
	end)

	trove:Add(Props.ActiveColor:Observe(function(newColor)
		if newColor then
			colorSwatch.BackgroundColor3 = newColor
		end
	end))

	-- Disabled Selection Message (Hidden by default)
	local disabledMessage = createText(colorSection, {
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		TextWrapped = true,
		TextColor3 = THEME.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.Gotham,
		LayoutOrder = 2,
		Visible = false,
	})

	-- Container for Hex Code
	local hexContainer = createFrame(colorSection, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Background,
		BorderColor3 = THEME.Border,
		BorderSizePixel = 1,
		LayoutOrder = 3,
	})
	local hexPadding = Instance.new("UIPadding")
	hexPadding.PaddingTop = UDim.new(0, 8)
	hexPadding.PaddingBottom = UDim.new(0, 8)
	hexPadding.PaddingLeft = UDim.new(0, 8)
	hexPadding.PaddingRight = UDim.new(0, 8)
	hexPadding.Parent = hexContainer
	local hexCorner = Instance.new("UICorner")
	hexCorner.CornerRadius = UDim.new(0, 8)
	hexCorner.Parent = hexContainer
	local hexLayout = Instance.new("UIListLayout")
	hexLayout.Padding = UDim.new(0, 8)
	hexLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hexLayout.Parent = hexContainer

	createText(hexContainer, {
		Text = "HEX COLOR",
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
	})

	createHexRow(hexContainer, "Hex", Props.ActiveColor, trove)

	-- Container for RGB
	local rgbContainer = createFrame(colorSection, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Background,
		BorderColor3 = THEME.Border,
		BorderSizePixel = 1,
		LayoutOrder = 4,
	})
	local rgbPadding = Instance.new("UIPadding")
	rgbPadding.PaddingTop = UDim.new(0, 8)
	rgbPadding.PaddingBottom = UDim.new(0, 8)
	rgbPadding.PaddingLeft = UDim.new(0, 8)
	rgbPadding.PaddingRight = UDim.new(0, 8)
	rgbPadding.Parent = rgbContainer
	local rgbCorner = Instance.new("UICorner")
	rgbCorner.CornerRadius = UDim.new(0, 8)
	rgbCorner.Parent = rgbContainer
	local rgbLayout = Instance.new("UIListLayout")
	rgbLayout.Padding = UDim.new(0, 8)
	rgbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rgbLayout.Parent = rgbContainer

	createText(rgbContainer, {
		Text = "RGB CHANNELS",
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
	})

	createColorSlider(rgbContainer, "Red", Props.ActiveColor, "R", trove, pluginGui)
	createColorSlider(rgbContainer, "Green", Props.ActiveColor, "G", trove, pluginGui)
	createColorSlider(rgbContainer, "Blue", Props.ActiveColor, "B", trove, pluginGui)

	-- Container for HSV
	local hsvContainer = createFrame(colorSection, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Background,
		BorderColor3 = THEME.Border,
		BorderSizePixel = 1,
		LayoutOrder = 5,
	})
	local hsvPadding = Instance.new("UIPadding")
	hsvPadding.PaddingTop = UDim.new(0, 8)
	hsvPadding.PaddingBottom = UDim.new(0, 8)
	hsvPadding.PaddingLeft = UDim.new(0, 8)
	hsvPadding.PaddingRight = UDim.new(0, 8)
	hsvPadding.Parent = hsvContainer
	local hsvCorner = Instance.new("UICorner")
	hsvCorner.CornerRadius = UDim.new(0, 8)
	hsvCorner.Parent = hsvContainer
	local hsvLayout = Instance.new("UIListLayout")
	hsvLayout.Padding = UDim.new(0, 8)
	hsvLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hsvLayout.Parent = hsvContainer

	createText(hsvContainer, {
		Text = "HSV CHANNELS",
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.TextMuted,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
	})

	createHSVSlider(hsvContainer, "Hue", Props.ActiveColor, "H", trove, pluginGui)
	createHSVSlider(hsvContainer, "Saturation", Props.ActiveColor, "S", trove, pluginGui)
	createHSVSlider(hsvContainer, "Value", Props.ActiveColor, "V", trove, pluginGui)

	-- 5. Selection Validation Logic
	trove:Add(Props.SelectedObjects:Observe(function()
		local isValidSelection, reason = ColorBehavior.ValidateSelectionForColoring()

		if isValidSelection then
			disabledMessage.Visible = false
			hexContainer.Visible = true
			rgbContainer.Visible = true
			hsvContainer.Visible = true
			colorSwatch.Visible = true
			eyedropperBtn.Visible = true
		else
			disabledMessage.Text = reason
			disabledMessage.Visible = true
			hexContainer.Visible = false
			rgbContainer.Visible = false
			hsvContainer.Visible = false
			colorSwatch.Visible = false
			eyedropperBtn.Visible = false
		end
	end))

	-- 6. Advanced Section
	local advancedSection = createFrame(mainScroll, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	})
	local advLayout = Instance.new("UIListLayout")
	advLayout.Padding = UDim.new(0, 8)
	advLayout.SortOrder = Enum.SortOrder.LayoutOrder
	advLayout.Parent = advancedSection

	createText(advancedSection, {
		Text = "Advanced",
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
	})

	local advancedRowContainer, advancedRow = createRow(advancedSection, "Keybinds")
	createToggle(advancedRowContainer, "Swap Y and Z keybinds", Props.SwapYandZKeybinds, trove)
	local advancedRowContainer2, advancedRow = createRow(advancedSection, "Keybinds")
	createToggle(advancedRowContainer2, "Origins Only", Props.OriginsOnly, trove)
end

return Widget
