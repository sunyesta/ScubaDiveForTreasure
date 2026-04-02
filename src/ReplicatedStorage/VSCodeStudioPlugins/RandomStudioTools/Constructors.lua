--!strict
-- This module contains reusable functions to generate UI components.
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local THEME = Config.THEME
local ICONS = Config.ICONS

local Constructors = {}

export type SelectOption = { Label: string, Value: any }

-- Helper function to generate standardized Section Containers
function Constructors.CreateSection(title: string, iconId: string, iconColor: Color3): (CanvasGroup, Frame)
	local section = Instance.new("CanvasGroup")
	section.Name = title .. "Section"
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundColor3 = THEME.Panel
	section.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = section

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Border
	stroke.Parent = section

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section

	local headerBg = Instance.new("TextButton")
	headerBg.Name = "Header"
	headerBg.Size = UDim2.new(1, 0, 0, 40)
	headerBg.BackgroundColor3 = THEME.PanelHeader
	headerBg.BorderSizePixel = 0
	headerBg.LayoutOrder = 1
	headerBg.Text = ""
	headerBg.AutoButtonColor = false

	local headerBorder = Instance.new("Frame")
	headerBorder.Name = "BottomBorder"
	headerBorder.Size = UDim2.new(1, 0, 0, 1)
	headerBorder.Position = UDim2.new(0, 0, 1, -1)
	headerBorder.BackgroundColor3 = THEME.Border
	headerBorder.BorderSizePixel = 0
	headerBorder.Visible = false -- Starting state: hidden
	headerBorder.Parent = headerBg

	local headerContent = Instance.new("Frame")
	headerContent.Name = "Content"
	headerContent.Size = UDim2.fromScale(1, 1)
	headerContent.BackgroundTransparency = 1
	headerContent.Parent = headerBg

	local headerLayoutInfo = Instance.new("UIListLayout")
	headerLayoutInfo.FillDirection = Enum.FillDirection.Horizontal
	headerLayoutInfo.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayoutInfo.Padding = UDim.new(0, 8)
	headerLayoutInfo.Parent = headerContent

	local hPadding = Instance.new("UIPadding")
	hPadding.PaddingLeft = UDim.new(0, 16)
	hPadding.Parent = headerContent

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = iconColor
	icon.Parent = headerContent

	local text = Instance.new("TextLabel")
	text.Name = "Title"
	text.Size = UDim2.fromScale(0, 0)
	text.AutomaticSize = Enum.AutomaticSize.XY
	text.BackgroundTransparency = 1
	text.Text = title
	text.TextColor3 = THEME.TextMain
	text.Font = Enum.Font.BuilderSansMedium
	text.TextSize = 14
	text.Parent = headerContent

	local chevron = Instance.new("ImageLabel")
	chevron.Name = "Chevron"
	chevron.Size = UDim2.new(0, 16, 0, 16)
	chevron.Position = UDim2.new(1, -16, 0.5, 0)
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.BackgroundTransparency = 1
	chevron.Image = ICONS.ArrowDown
	chevron.ImageColor3 = THEME.TextMuted
	chevron.Rotation = -90 -- Starting state: pointing right
	chevron.Parent = headerBg

	headerBg.Parent = section

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.LayoutOrder = 2
	body.Visible = false -- Starting state: hidden
	body.Parent = section

	-- Hover Effects
	headerBg.MouseEnter:Connect(function()
		headerBg.BackgroundColor3 = THEME.ButtonHoverBg
	end)

	headerBg.MouseLeave:Connect(function()
		headerBg.BackgroundColor3 = THEME.PanelHeader
	end)

	-- Toggle Logic
	local isOpen = false -- Starting state: closed
	headerBg.Activated:Connect(function()
		isOpen = not isOpen
		body.Visible = isOpen
		headerBorder.Visible = isOpen
		chevron.Rotation = isOpen and 0 or -90
	end)

	return section, body
end

function Constructors.CreateInputField(order: number, labelName: string, placeholder: string): Frame
	local fieldWrap = Instance.new("Frame")
	fieldWrap.Name = "FieldWrap"
	fieldWrap.Size = UDim2.new(1, 0, 0, 0)
	fieldWrap.AutomaticSize = Enum.AutomaticSize.Y
	fieldWrap.BackgroundTransparency = 1
	fieldWrap.LayoutOrder = order

	local fieldLayout = Instance.new("UIListLayout")
	fieldLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fieldLayout.Padding = UDim.new(0, 6)
	fieldLayout.Parent = fieldWrap

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Text = labelName
	label.TextColor3 = THEME.TextMuted
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = 1
	label.Parent = fieldWrap

	local inputContainer = Instance.new("Frame")
	inputContainer.Name = "InputContainer"
	inputContainer.Size = UDim2.new(1, 0, 0, 42)
	inputContainer.BackgroundColor3 = THEME.InputBg
	inputContainer.LayoutOrder = 2

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 12)
	inputCorner.Parent = inputContainer

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = THEME.Border
	inputStroke.Parent = inputContainer

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 36)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = inputContainer

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.Position = UDim2.new(0, -22, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = ICONS.Search
	icon.ImageColor3 = THEME.BorderLight
	icon.Parent = inputContainer

	local textBox = Instance.new("TextBox")
	textBox.Name = "TextBox"
	textBox.Size = UDim2.fromScale(1, 1)
	textBox.BackgroundTransparency = 1
	textBox.PlaceholderText = placeholder
	textBox.PlaceholderColor3 = THEME.BorderLight
	textBox.Text = ""
	textBox.TextColor3 = THEME.TextMain
	textBox.Font = Enum.Font.BuilderSans
	textBox.TextSize = 14
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.Parent = inputContainer

	inputContainer.Parent = fieldWrap
	return fieldWrap
end

-- Generates a toggleable checkbox switch
-- Returns the Container Frame and a BindableEvent that fires with the new boolean state
function Constructors.CreateCheckbox(order: number, labelName: string, defaultState: boolean): (Frame, BindableEvent)
	local container = Instance.new("Frame")
	container.Name = "CheckboxContainer"
	container.Size = UDim2.new(1, 0, 0, 32)
	container.BackgroundTransparency = 1
	container.LayoutOrder = order

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -50, 1, 0)
	label.Position = UDim2.new(0, 50, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelName
	label.TextColor3 = THEME.TextMuted
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local toggleBg = Instance.new("Frame")
	toggleBg.Name = "ToggleBackground"
	toggleBg.Size = UDim2.new(0, 40, 0, 24)
	toggleBg.Position = UDim2.new(0, 0, 0.5, -12)
	-- Fallback dynamically in case THEME.Primary or THEME.SectionBg are missing from Config
	toggleBg.BackgroundColor3 = defaultState and (THEME.Blue or Color3.fromRGB(37, 99, 235))
		or (THEME.PanelHeader or Color3.fromRGB(25, 35, 50))
	toggleBg.Parent = container

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = toggleBg

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = defaultState and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = toggleBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local btn = Instance.new("TextButton")
	btn.Name = "Hitbox"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = container

	local isChecked = defaultState
	local onChangeEvent = Instance.new("BindableEvent")

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	btn.Activated:Connect(function()
		isChecked = not isChecked

		-- Animate Color and Knob Position
		local goalPos = isChecked and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
		local goalColor = isChecked and (THEME.Blue or Color3.fromRGB(37, 99, 235))
			or (THEME.PanelHeader or Color3.fromRGB(25, 35, 50))

		TweenService:Create(knob, tweenInfo, { Position = goalPos }):Play()
		TweenService:Create(toggleBg, tweenInfo, { BackgroundColor3 = goalColor }):Play()

		-- Fire the event so other scripts know the state changed
		onChangeEvent:Fire(isChecked)
	end)

	return container, onChangeEvent
end

-- Generates a multi-select segmented control (chips)
-- Returns the Container Frame and a BindableEvent that fires with a table of currently selected values
function Constructors.CreateMultiSelect(
	order: number,
	labelName: string,
	options: { SelectOption },
	defaultSelections: { any }?
): (Frame, BindableEvent)
	local container = Instance.new("Frame")
	container.Name = "MultiSelectContainer"
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.BackgroundTransparency = 1
	container.LayoutOrder = order

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Text = labelName
	label.TextColor3 = THEME.TextMuted
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = 1
	label.Parent = container

	local optionsWrap = Instance.new("Frame")
	optionsWrap.Name = "OptionsWrap"
	optionsWrap.Size = UDim2.new(1, 0, 0, 32)
	optionsWrap.BackgroundColor3 = THEME.PanelHeader -- Updated default fallback
	optionsWrap.LayoutOrder = 2
	optionsWrap.Parent = container

	local wrapCorner = Instance.new("UICorner")
	wrapCorner.CornerRadius = UDim.new(0, 6)
	wrapCorner.Parent = optionsWrap

	local optionsLayout = Instance.new("UIListLayout")
	optionsLayout.FillDirection = Enum.FillDirection.Horizontal
	optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionsLayout.Parent = optionsWrap

	-- Keep track of active selections in a dictionary for easy lookups
	local activeSelections = {}
	if defaultSelections then
		for _, val in ipairs(defaultSelections) do
			activeSelections[val] = true
		end
	end

	local onChangeEvent = Instance.new("BindableEvent")
	local buttonWidth = 1 / #options

	for _, opt in ipairs(options) do
		local isSelected = activeSelections[opt.Value] == true

		local btn = Instance.new("TextButton")
		btn.Name = opt.Label
		btn.Size = UDim2.new(buttonWidth, 0, 1, 0)
		btn.Text = opt.Label
		btn.Font = Enum.Font.BuilderSansMedium
		btn.TextSize = 12
		btn.BackgroundColor3 = THEME.Blue -- Updated default fallback
		btn.BackgroundTransparency = isSelected and 0 or 1
		btn.TextColor3 = isSelected and Color3.new(1, 1, 1) or THEME.TextMuted
		btn.AutoButtonColor = false
		btn.Parent = optionsWrap

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn

		btn.Activated:Connect(function()
			-- Toggle selection state
			activeSelections[opt.Value] = not activeSelections[opt.Value]
			local currentlySelected = activeSelections[opt.Value]

			-- Update visuals
			btn.BackgroundTransparency = currentlySelected and 0 or 1
			btn.TextColor3 = currentlySelected and Color3.new(1, 1, 1) or THEME.TextMuted

			-- Compile an array of selected values to send out
			local currentSelectionArray = {}
			for val, active in pairs(activeSelections) do
				if active then
					table.insert(currentSelectionArray, val)
				end
			end

			onChangeEvent:Fire(currentSelectionArray)
		end)
	end

	return container, onChangeEvent
end

return Constructors
