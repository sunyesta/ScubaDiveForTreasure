--!strict
-- Figma to Roblox JSON Importer Plugin
-- Handles responsive coordinate mapping, property sync, and developer workflow safety.

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Ensure this script is running as a plugin
if not plugin then
	return
end

--------------------------------------------------------------------------------
-- 1. Interface & Interaction Setup
--------------------------------------------------------------------------------
local toolbar = plugin:CreateToolbar("Figma Tools")
local pluginButton = toolbar:CreateButton(
	"Start",
	"Toggle Figma JSON Input",
	"rbxassetid://137558628333270", -- Using the placeholder image as the icon
	"Start"
)

-- Create a Dockable Widget
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false, -- Widget does not start enabled
	false, -- Widget cannot override previous state initially
	300,
	250, -- Default Size (Increased slightly for new UI)
	200,
	200 -- Minimum Size
)

local widget = plugin:CreateDockWidgetPluginGui("FigmaImporterWidget", widgetInfo)
widget.Title = "Figma to Roblox JSON"

-- Create Widget UI
local bgFrame = Instance.new("Frame")
bgFrame.Size = UDim2.new(1, 0, 1, 0)
bgFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
bgFrame.Parent = widget

-- Configuration Frame for Base Resolution
local configFrame = Instance.new("Frame")
configFrame.Size = UDim2.new(1, 0, 0, 40)
configFrame.BackgroundTransparency = 1
configFrame.Parent = bgFrame

local resXBox = Instance.new("TextBox")
resXBox.Size = UDim2.new(0.5, -15, 1, -10)
resXBox.Position = UDim2.new(0, 10, 0, 5)
resXBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
resXBox.TextColor3 = Color3.fromRGB(255, 255, 255)
resXBox.PlaceholderText = "Figma W (1920)"
resXBox.Text = "1920"
resXBox.Parent = configFrame

local resYBox = Instance.new("TextBox")
resYBox.Size = UDim2.new(0.5, -15, 1, -10)
resYBox.Position = UDim2.new(0.5, 5, 0, 5)
resYBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
resYBox.TextColor3 = Color3.fromRGB(255, 255, 255)
resYBox.PlaceholderText = "Figma H (1080)"
resYBox.Text = "1080"
resYBox.Parent = configFrame

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -20, 1, -50)
inputBox.Position = UDim2.new(0, 10, 0, 40)
inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.PlaceholderText = "Paste Figma JSON here..."
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.TextYAlignment = Enum.TextYAlignment.Top
inputBox.ClearTextOnFocus = true
inputBox.Text = ""
inputBox.TextWrapped = true
inputBox.Parent = bgFrame

-- Toggle Widget Visibility
pluginButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

--------------------------------------------------------------------------------
-- 2. Intelligent Coordinate Mapping Helpers
--------------------------------------------------------------------------------

-- Helper to grab the Base Resolution from the UI TextBoxes
local function GetBaseResolution(): Vector2
	local x = tonumber(resXBox.Text) or 1920
	local y = tonumber(resYBox.Text) or 1080
	return Vector2.new(x, y)
end

-- Converts absolute Figma pixel coordinates to an Offset UDim2 natively in Figma-space
local function AbsoluteToOffsetPosition(guiObject: GuiObject, absolutePosition: Vector2): UDim2
	local figmaBaseRes = GetBaseResolution()
	local viewport = workspace.CurrentCamera.ViewportSize

	local function getAnchorOffset(gObj: GuiObject): Vector2
		-- Convert live anchor offset to Figma space equivalent
		local liveOffsetX = gObj.AnchorPoint.X * gObj.AbsoluteSize.X
		local liveOffsetY = gObj.AnchorPoint.Y * gObj.AbsoluteSize.Y
		return Vector2.new((liveOffsetX / viewport.X) * figmaBaseRes.X, (liveOffsetY / viewport.Y) * figmaBaseRes.Y)
	end

	local parentGui = guiObject:FindFirstAncestorWhichIsA("GuiObject")

	local parentFigmaAbsolutePosition = Vector2.new(0, 0)
	if parentGui then
		-- Convert the parent's Roblox AbsolutePosition into a Figma Canvas AbsolutePosition
		parentFigmaAbsolutePosition = Vector2.new(
			(parentGui.AbsolutePosition.X / viewport.X) * figmaBaseRes.X,
			(parentGui.AbsolutePosition.Y / viewport.Y) * figmaBaseRes.Y
		)
	end

	local relativePosition = absolutePosition + getAnchorOffset(guiObject) - parentFigmaAbsolutePosition
	return UDim2.fromOffset(relativePosition.X, relativePosition.Y)
end

-- Converts an Offset UDim2 to a Scale UDim2 utilizing the Figma Base Resolution
local function UDim2ToScale(parentGui: GuiObject?, udim2: UDim2): UDim2
	local figmaBaseRes = GetBaseResolution()
	local ParentAbsoluteSize

	if parentGui then
		-- Deduce the expected Figma size of the parent based on its Scale properties
		local scaleX, scaleY = 1, 1
		local current = parentGui
		while current and current:IsA("GuiObject") do
			scaleX = scaleX * current.Size.X.Scale
			scaleY = scaleY * current.Size.Y.Scale
			current = current.Parent
		end

		if scaleX == 0 or scaleY == 0 then
			-- Fallback to a proportional size if the hierarchy uses Offset sizing natively
			local viewport = workspace.CurrentCamera.ViewportSize
			ParentAbsoluteSize = Vector2.new(
				(parentGui.AbsoluteSize.X / viewport.X) * figmaBaseRes.X,
				(parentGui.AbsoluteSize.Y / viewport.Y) * figmaBaseRes.Y
			)
		else
			ParentAbsoluteSize = Vector2.new(figmaBaseRes.X * scaleX, figmaBaseRes.Y * scaleY)
		end
	else
		ParentAbsoluteSize = figmaBaseRes
	end

	local function OffsetToScale(offset: number, parentSize: number): number
		if parentSize == 0 then
			return 0
		end
		return offset / parentSize
	end

	return UDim2.new(
		udim2.X.Scale + OffsetToScale(udim2.X.Offset, ParentAbsoluteSize.X),
		0,
		udim2.Y.Scale + OffsetToScale(udim2.Y.Offset, ParentAbsoluteSize.Y),
		0
	)
end

--------------------------------------------------------------------------------
-- 3. Property Synchronization & Logic
--------------------------------------------------------------------------------

local function ApplyFigmaData(target: GuiObject, data: any)
	local parentGui = target:FindFirstAncestorWhichIsA("GuiObject")

	-- Apply Size and Position (Responsive Scale based on Base Resolution)
	if data.width and data.height then
		target.Size = UDim2ToScale(parentGui, UDim2.new(0, data.width, 0, data.height))
	end

	if data.x and data.y then
		target.Position = UDim2ToScale(parentGui, AbsoluteToOffsetPosition(target, Vector2.new(data.x, data.y)))
	end

	-- Opacity / Background Transparency
	local figmaOpacity = data.opacity or 1
	target.BackgroundTransparency = 1 - figmaOpacity

	-- Fills (Colors & Images)
	if data.fills and #data.fills > 0 then
		local fill = data.fills[1]

		if fill.type == "SOLID" then
			local color = fill.color
			target.BackgroundColor3 = Color3.new(color.r, color.g, color.b)

			-- Combine element opacity with fill opacity
			local fillOpacity = fill.opacity or 1
			target.BackgroundTransparency = 1 - (figmaOpacity * fillOpacity)
		elseif fill.type == "IMAGE" then
			if target:IsA("ImageLabel") or target:IsA("ImageButton") then
				target.Image = "rbxassetid://137558628333270"
				target.ScaleType = Enum.ScaleType.Fit
				target.BackgroundTransparency = 1 -- Usually backgrounds are transparent behind images
			else
				warn("Figma JSON has an IMAGE fill, but selected object does not support Images.")
			end
		end
	else
		target.BackgroundTransparency = 1 -- No fills = completely transparent
	end

	-- Text Support
	if data.type == "TEXT" then
		if target:IsA("TextLabel") or target:IsA("TextButton") or target:IsA("TextBox") then
			target.Text = data.characters or "Text"

			if data.fontSize then
				target.TextSize = data.fontSize
			end

			-- Text Color matches the first solid fill
			if data.fills and #data.fills > 0 and data.fills[1].type == "SOLID" then
				local color = data.fills[1].color
				target.TextColor3 = Color3.new(color.r, color.g, color.b)
			end

			-- Try to match font
			if data.fontName and data.fontName.family then
				local success, fontEnum = pcall(function()
					-- Simple font matching attempt. Note: Figma font names don't perfectly match Roblox enums
					return Enum.Font[data.fontName.family]
				end)
				if success and fontEnum then
					target.Font = fontEnum
				end
			end

			-- Background is usually transparent for pure text blocks in Figma
			target.BackgroundTransparency = 1
		else
			warn("Figma JSON is type TEXT, but selected object does not support Text.")
		end
	end

	-- Rounded Corners (UICorner)
	if data.cornerRadius and data.cornerRadius > 0 then
		local corner = target:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = target
		end
		-- Set CornerRadius using Scale (legacy logic for proportional curves)
		corner.CornerRadius = UDim.new(data.cornerRadius / math.min(target.AbsoluteSize.X, target.AbsoluteSize.Y), 0)
	else
		-- Remove existing corner if Figma doesn't have one
		local corner = target:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Destroy()
		end
	end

	-- Borders (UIStroke)
	if data.strokes and #data.strokes > 0 then
		local strokeData = data.strokes[1]
		local stroke = target:FindFirstChildOfClass("UIStroke")

		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = target
		end

		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize

		-- Calculate the relative scale to match Figma's pixel stroke weight
		local figmaStrokeWeight = data.strokeWeight or 1
		local minDimension = math.min(target.AbsoluteSize.X, target.AbsoluteSize.Y)

		if minDimension > 0 then
			stroke.Thickness = figmaStrokeWeight / minDimension
		else
			stroke.Thickness = 0
		end

		-- Detect the inner/outer alignment (Noted here for reference)
		-- In Roblox, UIStroke ApplyStrokeMode.Border automatically surrounds the UI seamlessly.
		local strokeAlign = data.strokeAlign or "CENTER"

		if strokeData.type == "SOLID" and strokeData.color then
			local c = strokeData.color
			stroke.Color = Color3.new(c.r, c.g, c.b)
			stroke.Transparency = 1 - (strokeData.opacity or 1)
		end
	else
		local stroke = target:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- 4. Safety & Processing Logic
--------------------------------------------------------------------------------

inputBox.FocusLost:Connect(function(enterPressed: boolean)
	local jsonText = inputBox.Text
	if jsonText == "" then
		return
	end

	-- 4a. Validate JSON
	local success, parsedData = pcall(function()
		return HttpService:JSONDecode(jsonText)
	end)

	if not success then
		warn("Figma Importer: Invalid JSON format.")
		return
	end

	if type(parsedData) ~= "table" or not parsedData[1] then
		warn("Figma Importer: Please provide valid elements in the JSON array.")
		return
	end

	local figmaData = parsedData[1]

	-- Validate Rotation
	if figmaData.rotation and math.abs(figmaData.rotation) >= 1 then
		warn("Figma Importer: Gui rotations not supported! Please set rotation to 0 in Figma and try again.")
		return
	end

	-- 4b. Validate Selection
	local selected = Selection:Get()
	if #selected ~= 1 or not selected[1]:IsA("GuiObject") then
		warn("Figma Importer: Please select exactly ONE GuiObject in your Explorer.")
		return
	end

	local target: GuiObject = selected[1]

	-- 4c. Undo/Redo Support Implementation
	ChangeHistoryService:SetWaypoint("BeforeFigmaImport")

	-- Apply properties
	ApplyFigmaData(target, figmaData)

	-- Finalize waypoint
	ChangeHistoryService:SetWaypoint("AfterFigmaImport")

	-- Clear input box for next use
	inputBox.Text = ""
	print("Figma properties successfully applied to " .. target.Name)
end)
