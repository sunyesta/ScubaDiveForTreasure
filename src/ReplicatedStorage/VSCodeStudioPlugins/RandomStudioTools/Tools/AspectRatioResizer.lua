--!strict
-- This script runs on the Server/Studio context and handles the Aspect Ratio resizing UI and logic.
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local AspectRatioResizer = {}

-- Helper function to safely evaluate the user's input string (e.g. "1.77" or "16/9")
local function evaluateInput(str: string): number?
	if not str or str == "" then
		return nil
	end

	-- 1. Try direct number conversion
	local directNum = tonumber(str)
	if directNum then
		return directNum
	end

	-- 2. Try parsing simple division manually (e.g., "16/9")
	local numeratorStr, denominatorStr = string.match(str, "^%s*([%d%.]+)%s*/%s*([%d%.]+)%s*$")
	if numeratorStr and denominatorStr then
		local n = tonumber(numeratorStr)
		local d = tonumber(denominatorStr)
		if n and d and d ~= 0 then
			return n / d
		end
	end

	-- 3. Fallback: Try loadstring for other math (e.g. "5 * 2")
	local ls: any = loadstring
	if ls then
		local success, result = pcall(function()
			local func = ls("return " .. str)
			if func then
				return func()
			end
			return nil
		end)

		if success and type(result) == "number" then
			return result
		end
	end

	return nil
end

-- Constructs the Aspect Ratio Resizer section and returns the assembled CanvasGroup
function AspectRatioResizer.Create(): CanvasGroup
	-- 1. Create the Section Outline using the universal constructor
	local section, body = Constructors.CreateSection("Aspect Ratio Resizer", ICONS.Layout, THEME.Blue)

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingTop = UDim.new(0, 16)
	bodyPadding.PaddingBottom = UDim.new(0, 16)
	bodyPadding.PaddingLeft = UDim.new(0, 16)
	bodyPadding.PaddingRight = UDim.new(0, 16)
	bodyPadding.Parent = body

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = body

	-- 2. Create the Input Field using the constructor
	local inputFieldWrap = Constructors.CreateInputField(1, "Target Aspect Ratio (X / Y)", "e.g. 1.77 or 16/9")
	inputFieldWrap.Parent = body

	-- Extract the actual TextBox instance so we can read its Text later
	local inputContainer = inputFieldWrap:FindFirstChild("InputContainer")
	local textBox: TextBox? = nil
	if inputContainer then
		textBox = inputContainer:FindFirstChild("TextBox") :: TextBox
		if textBox then
			textBox.Text = "16/9" -- Default value
		end
	end

	-- 3. Create the Execution Button
	local resizeBtn = Instance.new("TextButton")
	resizeBtn.Name = "ResizeButton"
	resizeBtn.Size = UDim2.new(1, 0, 0, 44)
	resizeBtn.BackgroundColor3 = THEME.Blue
	resizeBtn.Text = "Resize Selected"
	resizeBtn.TextColor3 = Color3.new(1, 1, 1)
	resizeBtn.Font = Enum.Font.BuilderSansMedium
	resizeBtn.TextSize = 14
	resizeBtn.LayoutOrder = 2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = resizeBtn

	resizeBtn.Parent = body

	-- 4. Setup the Logic
	resizeBtn.Activated:Connect(function()
		if not textBox then
			return
		end

		local ratio = evaluateInput(textBox.Text)

		if not ratio then
			warn("[Random Studio Tools] Invalid aspect ratio input. Please enter a number or fraction (e.g. '16/9').")
			return
		end

		local selectedInstances = Selection:Get()
		local partsResized = 0

		-- Create a waypoint so the user can 'Ctrl + Z' to undo this action
		ChangeHistoryService:SetWaypoint("BeforeAspectResize")

		for _, obj in ipairs(selectedInstances) do
			if obj:IsA("BasePart") then
				-- Priority Axis is Y. Aspect Ratio = X / Y, therefore X = Y * AspectRatio
				local currentY = obj.Size.Y
				local currentZ = obj.Size.Z
				local newX = currentY * ratio

				obj.Size = Vector3.new(newX, currentY, currentZ)
				partsResized += 1
			end
		end

		if partsResized > 0 then
			-- Close the waypoint to complete the undo history state
			ChangeHistoryService:SetWaypoint("AfterAspectResize")
			print(string.format("[Random Studio Tools] Resized %d parts. Calculated Ratio: %.3f", partsResized, ratio))
		else
			warn("[Random Studio Tools] No BaseParts selected to resize.")
		end
	end)

	return section
end

return AspectRatioResizer
