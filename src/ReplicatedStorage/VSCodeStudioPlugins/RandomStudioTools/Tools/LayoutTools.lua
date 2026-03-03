--!strict
local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local LayoutTools = {}

-- Constructs the Layout Tools section and returns the assembled CanvasGroup
function LayoutTools.Create(): CanvasGroup
	local layoutSection, layoutBody = Constructors.CreateSection("Layout Tools", ICONS.Layout, THEME.Indigo)

	local layoutBodyPadding = Instance.new("UIPadding")
	layoutBodyPadding.PaddingTop = UDim.new(0, 16)
	layoutBodyPadding.PaddingBottom = UDim.new(0, 16)
	layoutBodyPadding.PaddingLeft = UDim.new(0, 16)
	layoutBodyPadding.PaddingRight = UDim.new(0, 16)
	layoutBodyPadding.Parent = layoutBody

	local layoutBodyLayout = Instance.new("UIListLayout")
	layoutBodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	layoutBodyLayout.Parent = layoutBody

	local organizeBtn = Instance.new("TextButton")
	organizeBtn.Name = "OrganizeButton"
	organizeBtn.Size = UDim2.new(1, 0, 0, 48)
	organizeBtn.BackgroundColor3 = THEME.Indigo
	organizeBtn.Text = "Organize Selected into Grid"
	organizeBtn.TextColor3 = Color3.new(1, 1, 1)
	organizeBtn.Font = Enum.Font.BuilderSansMedium
	organizeBtn.TextSize = 14

	local organizeCorner = Instance.new("UICorner")
	organizeCorner.CornerRadius = UDim.new(0, 12)
	organizeCorner.Parent = organizeBtn

	organizeBtn.Parent = layoutBody

	return layoutSection
end

return LayoutTools
