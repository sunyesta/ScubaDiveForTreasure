--!strict
local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local SETTING_KEY = "CameraSaver_Positions_v1"

local CameraPositions = {}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Convert CFrame to an array of numbers for DataStore/Plugin storage
local function serializeCFrame(cf: CFrame): { number }
	return { cf:GetComponents() }
end

-- Convert array of numbers back into a CFrame
local function deserializeCFrame(data: { number }?): CFrame?
	if not data then
		return nil
	end
	return CFrame.new(table.unpack(data))
end

--------------------------------------------------------------------------------
-- Slot Constructor
--------------------------------------------------------------------------------

local function CreateCamSlot(
	order: number,
	slotName: string,
	isActive: boolean,
	pluginObj: Plugin?,
	savedPositions: { [number]: CFrame }
): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. order
	slot.Size = UDim2.new(1, 0, 0, 50)
	slot.BackgroundTransparency = 1
	slot.LayoutOrder = order

	local slotPadding = Instance.new("UIPadding")
	slotPadding.PaddingLeft = UDim.new(0, 16)
	slotPadding.PaddingRight = UDim.new(0, 16)
	slotPadding.Parent = slot

	if order < 3 then
		local slotBorder = Instance.new("Frame")
		slotBorder.Name = "BottomBorder"
		slotBorder.Size = UDim2.new(1, 32, 0, 1)
		slotBorder.Position = UDim2.new(0, -16, 1, -1)
		slotBorder.BackgroundColor3 = THEME.Border
		slotBorder.BorderSizePixel = 0
		slotBorder.Parent = slot
	end

	local infoGroup = Instance.new("Frame")
	infoGroup.Name = "InfoGroup"
	infoGroup.Size = UDim2.new(1, -90, 1, 0)
	infoGroup.BackgroundTransparency = 1

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Horizontal
	infoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	infoLayout.Padding = UDim.new(0, 12)
	infoLayout.Parent = infoGroup

	local numBox = Instance.new("Frame")
	numBox.Name = "NumBox"
	numBox.Size = UDim2.new(0, 24, 0, 24)
	numBox.BackgroundColor3 = THEME.PanelHeader

	local numCorner = Instance.new("UICorner")
	numCorner.CornerRadius = UDim.new(0, 4)
	numCorner.Parent = numBox

	local numStroke = Instance.new("UIStroke")
	numStroke.Color = THEME.Border
	numStroke.Parent = numBox

	local numText = Instance.new("TextLabel")
	numText.Name = "Text"
	numText.Size = UDim2.fromScale(1, 1)
	numText.BackgroundTransparency = 1
	numText.Text = tostring(order)
	numText.TextColor3 = THEME.TextMuted
	numText.Font = Enum.Font.BuilderSansBold
	numText.TextSize = 12
	numText.Parent = numBox
	numBox.Parent = infoGroup

	local nameText = Instance.new("TextLabel")
	nameText.Name = "Name"
	nameText.Size = UDim2.fromScale(0, 0)
	nameText.AutomaticSize = Enum.AutomaticSize.XY
	nameText.BackgroundTransparency = 1
	nameText.Text = slotName
	nameText.TextColor3 = isActive and THEME.TextMain or THEME.TextMuted
	nameText.Font = Enum.Font.BuilderSansMedium
	nameText.TextSize = 14
	nameText.Parent = infoGroup
	infoGroup.Parent = slot

	local actionsGroup = Instance.new("Frame")
	actionsGroup.Name = "ActionsGroup"
	actionsGroup.Size = UDim2.fromScale(0, 1)
	actionsGroup.Position = UDim2.fromScale(1, 0)
	actionsGroup.AnchorPoint = Vector2.new(1, 0)
	actionsGroup.AutomaticSize = Enum.AutomaticSize.X
	actionsGroup.BackgroundTransparency = 1

	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionsLayout.Padding = UDim.new(0, 8)
	actionsLayout.Parent = actionsGroup

	local saveBtn = Instance.new("ImageButton")
	saveBtn.Name = "SaveBtn"
	saveBtn.Size = UDim2.new(0, 36, 0, 36)
	saveBtn.BackgroundColor3 = THEME.PanelHeader
	saveBtn.Image = ICONS.Save
	saveBtn.ImageColor3 = isActive and THEME.Emerald or THEME.TextMuted

	local saveCorner = Instance.new("UICorner")
	saveCorner.CornerRadius = UDim.new(0, 8)
	saveCorner.Parent = saveBtn

	local saveStroke = Instance.new("UIStroke")
	saveStroke.Color = THEME.Border
	saveStroke.Parent = saveBtn
	saveBtn.Parent = actionsGroup

	local playBtn = Instance.new("ImageButton")
	playBtn.Name = "PlayBtn"
	playBtn.Size = UDim2.new(0, 36, 0, 36)
	playBtn.BackgroundColor3 = isActive and THEME.EmeraldDark or THEME.PanelHeader
	playBtn.Image = ICONS.Play
	playBtn.ImageColor3 = isActive and THEME.Emerald or THEME.TextMuted

	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 8)
	playCorner.Parent = playBtn

	local playStroke = Instance.new("UIStroke")
	playStroke.Color = isActive and THEME.Emerald or THEME.Border
	playStroke.Transparency = isActive and 0.8 or 0
	playStroke.Parent = playBtn
	playBtn.Parent = actionsGroup

	actionsGroup.Parent = slot

	----------------------------------------------------------------------------
	-- Plugin Logic Connections
	----------------------------------------------------------------------------

	-- SAVE LOGIC
	saveBtn.MouseButton1Click:Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			-- 1. Save to local table memory
			savedPositions[order] = cam.CFrame

			-- 2. Save to plugin's persistent storage (if plugin object was provided)
			if pluginObj then
				local serialized = {}
				for i, cf in pairs(savedPositions) do
					serialized[i] = serializeCFrame(cf)
				end
				pluginObj:SetSetting(SETTING_KEY, serialized)
			end

			-- 3. Visual Feedback (Flash Emerald)
			local originalColor = saveBtn.ImageColor3
			saveBtn.ImageColor3 = THEME.Emerald
			task.wait(0.7)
			saveBtn.ImageColor3 = originalColor
		end
	end)

	-- LOAD LOGIC
	playBtn.MouseButton1Click:Connect(function()
		local cf = savedPositions[order]
		if cf then
			local cam = workspace.CurrentCamera
			if cam then
				cam.CFrame = cf
				-- Update focus so the pivot point moves correctly
				cam.Focus = cf * CFrame.new(0, 0, -10)
			end
		else
			-- Visual Feedback if empty (Flash Red)
			local originalColor = playBtn.ImageColor3
			playBtn.ImageColor3 = Color3.fromRGB(255, 80, 80)
			task.wait(0.7)
			playBtn.ImageColor3 = originalColor
		end
	end)

	return slot
end

--------------------------------------------------------------------------------
-- Main Constructor
--------------------------------------------------------------------------------

-- Constructs the Camera Positions section and returns the assembled CanvasGroup
-- Note: Pass the `plugin` global variable into this function from your main server script!
function CameraPositions.Create(pluginObj: Plugin?): CanvasGroup
	local camSection, camBody = Constructors.CreateSection("Camera Positions", ICONS.Camera, THEME.Emerald)

	local camListLayout = Instance.new("UIListLayout")
	camListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	camListLayout.Parent = camBody

	-- State table to hold our CFrames in memory
	local savedPositions: { [number]: CFrame } = {}

	-- Load previously saved positions on startup
	if pluginObj then
		local success, loadedData = pcall(function()
			return pluginObj:GetSetting(SETTING_KEY)
		end)

		if success and loadedData and type(loadedData) == "table" then
			for i, data in pairs(loadedData :: any) do
				savedPositions[i] = deserializeCFrame(data)
			end
		end
	end

	-- Generate camera slots, passing down the plugin object and the state table
	CreateCamSlot(1, "Save 1", true, pluginObj, savedPositions).Parent = camBody
	CreateCamSlot(2, "Save 2", false, pluginObj, savedPositions).Parent = camBody
	CreateCamSlot(3, "Save 3", false, pluginObj, savedPositions).Parent = camBody

	return camSection
end

return CameraPositions
