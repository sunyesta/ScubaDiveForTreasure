--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Constructors = require(script.Parent.Constructors)

local LayoutTools = require(script.Parent.Tools.LayoutTools)
local CameraPositions = require(script.Parent.Tools.CameraPositions)
local AssetOperations = require(script.Parent.Tools.AssetOperations)
local ReplaceMesh = require(script.Parent.Tools.ReplaceMesh)
local SpecialMeshConverter = require(script.Parent.Tools.SpecialMeshConverter)
local AutoPrimaryPart = require(script.Parent.Tools.AutoPrimaryPart)
local SelectSimilar = require(script.Parent.Tools.SelectSimilar)
local AspectRatioResizer = require(script.Parent.Tools.AspectRatioResizer)
local MoveTool = require(script.Parent.Tools.MoveTool)
local WeldTool = require(script.Parent.Tools.WeldTool) -- NEW REQUIRED MODULE

local THEME = Config.THEME
local ICONS = Config.ICONS

local Widget = {}

function Widget.Init(plugin: Plugin, pluginTrove: any)
	-- [[ 1. CREATE DOCK WIDGET ]] --
	local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false, 350, 600, 300, 400)

	local gui = plugin:CreateDockWidgetPluginGui("RemoteControllerWidget", widgetInfo)
	gui.Title = "Remote Controller"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = true

	-- [[ 2. MAIN CONTAINER ]] --
	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "MainContainer"
	mainContainer.Size = UDim2.fromScale(1, 1)
	mainContainer.BackgroundColor3 = THEME.Background
	mainContainer.BorderSizePixel = 0

	-- [[ 3. HEADER ]] --
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = THEME.Background
	header.BorderSizePixel = 0
	header.ZIndex = 2

	local headerBorder = Instance.new("UIStroke")
	headerBorder.Color = THEME.Border
	headerBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerBorder.Parent = header

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, 20)
	headerPadding.PaddingRight = UDim.new(0, 20)
	headerPadding.Parent = header

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Parent = header

	-- Header: Left Group (Icon + Main Title)
	local headerLeftGroup = Instance.new("Frame")
	headerLeftGroup.Name = "LeftGroup"
	headerLeftGroup.Size = UDim2.new(1, -30, 1, 0)
	headerLeftGroup.BackgroundTransparency = 1

	local leftGroupLayout = Instance.new("UIListLayout")
	leftGroupLayout.FillDirection = Enum.FillDirection.Horizontal
	leftGroupLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftGroupLayout.Padding = UDim.new(0, 12)
	leftGroupLayout.Parent = headerLeftGroup

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.Size = UDim2.new(0, 32, 0, 32)
	iconBox.BackgroundColor3 = THEME.Background

	local iconBoxCorner = Instance.new("UICorner")
	iconBoxCorner.CornerRadius = UDim.new(1, 0)
	iconBoxCorner.Parent = iconBox

	local iconBoxStroke = Instance.new("UIStroke")
	iconBoxStroke.Color = THEME.Blue
	iconBoxStroke.Transparency = 0.7
	iconBoxStroke.Parent = iconBox

	local gamepadIcon = Instance.new("ImageLabel")
	gamepadIcon.Name = "Icon"
	gamepadIcon.Size = UDim2.new(0, 16, 0, 16)
	gamepadIcon.Position = UDim2.fromScale(0.5, 0.5)
	gamepadIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gamepadIcon.BackgroundTransparency = 1
	gamepadIcon.Image = ICONS.Gamepad
	gamepadIcon.ImageColor3 = THEME.Blue
	gamepadIcon.Parent = iconBox
	iconBox.Parent = headerLeftGroup

	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.fromScale(0, 0)
	titleContainer.AutomaticSize = Enum.AutomaticSize.XY
	titleContainer.BackgroundTransparency = 1

	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Vertical
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Parent = titleContainer

	local mainTitle = Instance.new("TextLabel")
	mainTitle.Name = "MainTitle"
	mainTitle.Size = UDim2.fromScale(0, 0)
	mainTitle.AutomaticSize = Enum.AutomaticSize.XY
	mainTitle.BackgroundTransparency = 1
	mainTitle.Text = "Random Studio Tools"
	mainTitle.TextColor3 = THEME.TextMain
	mainTitle.Font = Enum.Font.BuilderSansBold
	mainTitle.TextSize = 16
	mainTitle.Parent = titleContainer

	titleContainer.Parent = headerLeftGroup
	headerLeftGroup.Parent = header

	-- [[ 4. SCROLLING CONTENT ]] --
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ContentScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -60)
	scrollFrame.Position = UDim2.new(0, 0, 0, 60)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 0
	scrollFrame.CanvasSize = UDim2.fromScale(0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, 16)
	scrollPadding.PaddingBottom = UDim.new(0, 96)
	scrollPadding.PaddingLeft = UDim.new(0, 16)
	scrollPadding.PaddingRight = UDim.new(0, 16)
	scrollPadding.Parent = scrollFrame

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Vertical
	scrollLayout.Padding = UDim.new(0, 20)
	scrollLayout.Parent = scrollFrame

	-- [[ 4A. LAYOUT TOOLS SECTION ]] --
	local layoutSection = LayoutTools.Create()
	layoutSection.Parent = scrollFrame

	-- [[ 4B. CAMERA POSITIONS SECTION ]] --
	local camSection = CameraPositions.Create()
	camSection.Parent = scrollFrame

	-- [[ 4C. ASSET OPERATIONS SECTION ]] --
	local assetSection = AssetOperations.Create()
	assetSection.Parent = scrollFrame

	-- [[ 4D. REPLACE MESH SECTION ]] --
	local replaceMeshSection = ReplaceMesh.Create()
	replaceMeshSection.Parent = scrollFrame

	-- [[ 4E. SPECIAL MESH CONVERTER SECTION ]] --
	local specialMeshSection = SpecialMeshConverter.Create()
	specialMeshSection.Parent = scrollFrame

	-- [[ 4F. AUTO PRIMARY PART SECTION ]] --
	local autoPrimarySection = AutoPrimaryPart.Create()
	autoPrimarySection.Parent = scrollFrame

	-- [[ 4G. SELECT SIMILAR SECTION ]] --
	local selectSimilarSection = SelectSimilar.Create()
	selectSimilarSection.Parent = scrollFrame

	-- [[ 4H. ASPECT RATIO RESIZER SECTION ]] --
	local aspectSection = AspectRatioResizer.Create()
	aspectSection.Parent = scrollFrame

	-- [[ 4I. MOVE TOOL SECTION ]] --
	local moveToolSection = MoveTool.Create()
	moveToolSection.Parent = scrollFrame

	-- [[ 4J. WELD TOOL SECTION ]] --
	local weldToolSection = WeldTool.Create()
	weldToolSection.Parent = scrollFrame

	-- [[ 5. ASSEMBLE WIDGET ]] --
	header.Parent = mainContainer
	scrollFrame.Parent = mainContainer
	mainContainer.Parent = gui

	pluginTrove:Add(gui)

	return gui
end

return Widget
