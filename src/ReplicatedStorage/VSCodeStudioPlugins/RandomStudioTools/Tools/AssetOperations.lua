--!strict
local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local AssetOperations = {}

-- Constructs the Asset Operations section and returns the assembled CanvasGroup
function AssetOperations.Create(): CanvasGroup
	local assetSection, assetBody = Constructors.CreateSection("Asset Operations", ICONS.Search, THEME.Orange)

	local assetBodyPadding = Instance.new("UIPadding")
	assetBodyPadding.PaddingTop = UDim.new(0, 16)
	assetBodyPadding.PaddingBottom = UDim.new(0, 16)
	assetBodyPadding.PaddingLeft = UDim.new(0, 16)
	assetBodyPadding.PaddingRight = UDim.new(0, 16)
	assetBodyPadding.Parent = assetBody

	local assetListLayout = Instance.new("UIListLayout")
	assetListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	assetListLayout.Padding = UDim.new(0, 12)
	assetListLayout.Parent = assetBody

	-- Input Fields
	Constructors.CreateInputField(1, "Target Asset ID", "e.g. obj_tree_01").Parent = assetBody

	local arrowWrap = Instance.new("Frame")
	arrowWrap.Name = "ArrowWrap"
	arrowWrap.Size = UDim2.new(1, 0, 0, 0)
	arrowWrap.BackgroundTransparency = 1
	arrowWrap.LayoutOrder = 2
	arrowWrap.ZIndex = 2

	local arrowIconBg = Instance.new("Frame")
	arrowIconBg.Name = "IconBg"
	arrowIconBg.Size = UDim2.new(0, 24, 0, 24)
	arrowIconBg.Position = UDim2.fromScale(0.5, 0)
	arrowIconBg.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowIconBg.BackgroundColor3 = THEME.PanelHeader

	local arrowCorner = Instance.new("UICorner")
	arrowCorner.CornerRadius = UDim.new(1, 0)
	arrowCorner.Parent = arrowIconBg

	local arrowStroke = Instance.new("UIStroke")
	arrowStroke.Color = THEME.Border
	arrowStroke.Parent = arrowIconBg

	local downArrow = Instance.new("ImageLabel")
	downArrow.Name = "Arrow"
	downArrow.Size = UDim2.new(0, 12, 0, 12)
	downArrow.Position = UDim2.fromScale(0.5, 0.5)
	downArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	downArrow.BackgroundTransparency = 1
	downArrow.Image = ICONS.ArrowDown
	downArrow.ImageColor3 = THEME.BorderLight
	downArrow.Parent = arrowIconBg
	arrowIconBg.Parent = arrowWrap
	arrowWrap.Parent = assetBody

	Constructors.CreateInputField(3, "Replace With ID", "e.g. obj_tree_02_hd").Parent = assetBody

	local replaceBtn = Instance.new("TextButton")
	replaceBtn.Name = "ReplaceButton"
	replaceBtn.Size = UDim2.new(1, 0, 0, 44)
	replaceBtn.BackgroundColor3 = THEME.Orange
	replaceBtn.Text = "Replace All Instances"
	replaceBtn.TextColor3 = Color3.new(1, 1, 1)
	replaceBtn.Font = Enum.Font.BuilderSansMedium
	replaceBtn.TextSize = 14
	replaceBtn.LayoutOrder = 4

	local replaceCorner = Instance.new("UICorner")
	replaceCorner.CornerRadius = UDim.new(0, 12)
	replaceCorner.Parent = replaceBtn

	replaceBtn.Parent = assetBody

	return assetSection
end

return AssetOperations
