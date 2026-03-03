--!strict
-- This module contains reusable functions to generate UI components.
local Config = require(script.Parent:WaitForChild("Config"))
local THEME = Config.THEME
local ICONS = Config.ICONS

local Constructors = {}

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

return Constructors
