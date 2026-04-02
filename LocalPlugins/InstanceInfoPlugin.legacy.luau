--[[
    INSTANCE INFO EXTRACTOR PLUGIN (UPDATED)
    
    Features:
    - View Hierarchy, Tags, and Attributes.
    - Toggle "Show Properties" using a checkbox.
    - Uses HttpService to fetch the Roblox API Dump for true Reflection.
    
    Instructions:
    1. Save this code as a .lua file.
    2. Place in your Roblox Studio Plugins folder.
    3. IMPORTANT: Enable "Allow HTTP Requests" in Game Settings > Security 
       (Required to fetch the Property List).
]]

local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local SHOW_PROPERTIES = false
local API_DUMP_URL = "https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json"
local REMOTE_NAME = "InstanceInfoPlugin_ApiRemote"
local cachedApiDump = nil
local classPropertyCache = {} -- Cache for processed class properties

-- ==============================================================================
-- REMOTE FUNCTION SETUP (SERVER-SIDE)
-- ==============================================================================

-- If we are running on the Server during a Play Test, setup the RemoteFunction
if RunService:IsServer() and not RunService:IsEdit() then
	local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = REMOTE_NAME
		remote.Parent = ReplicatedStorage
	end

	remote.OnServerInvoke = function(player)
		-- Fetch the API dump and return the raw JSON string to the client
		local success, result = pcall(function()
			return HttpService:GetAsync(API_DUMP_URL)
		end)
		if success then
			return result
		end
		return nil
	end
end

-- Create the Toolbar and Button
local toolbar = plugin:CreateToolbar("Info Tools")
local toggleButton = toolbar:CreateButton(
	"Open Info", 
	"View selected instance hierarchy and info", 
	"rbxassetid://4458901833"
)
toggleButton.ClickableWhenViewportHidden = true

-- Create the Dock Widget
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	300,
	450,
	250,
	300
)

local widget = plugin:CreateDockWidgetPluginGui("InstanceInfoWidget", widgetInfo)
widget.Title = "Instance Information"

-- ==============================================================================
-- UI SETUP
-- ==============================================================================

-- 1. Control Bar (Top)
local controlFrame = Instance.new("Frame")
controlFrame.Name = "ControlFrame"
controlFrame.Size = UDim2.new(1, 0, 0, 40)
controlFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
controlFrame.BorderSizePixel = 0
controlFrame.Parent = widget

-- 2. Checkbox Button
local propCheckbox = Instance.new("TextButton")
propCheckbox.Name = "PropCheckbox"
propCheckbox.Size = UDim2.new(0, 150, 0, 30)
propCheckbox.Position = UDim2.new(0, 5, 0, 5)
propCheckbox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
propCheckbox.BorderSizePixel = 0
propCheckbox.Font = Enum.Font.SourceSansBold
propCheckbox.TextSize = 14
propCheckbox.TextColor3 = Color3.fromRGB(255, 255, 255)
propCheckbox.Text = "[ ] Show Properties"
propCheckbox.Parent = controlFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = propCheckbox

-- 3. Scrolling Frame (Bottom)
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Name = "ResultsFrame"
scrollingFrame.Size = UDim2.new(1, 0, 1, -40) -- Subtract controlFrame height
scrollingFrame.Position = UDim2.new(0, 0, 0, 40)
scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 0)
scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollingFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
scrollingFrame.BorderSizePixel = 0
scrollingFrame.Parent = widget

local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(1, -10, 1, -10)
textBox.Position = UDim2.new(0, 5, 0, 5)
textBox.MultiLine = true
textBox.ClearTextOnFocus = false
textBox.TextEditable = false
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.TextYAlignment = Enum.TextYAlignment.Top
textBox.Font = Enum.Font.Code
textBox.TextSize = 13
textBox.TextColor3 = Color3.fromRGB(220, 220, 220)
textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
textBox.Text = "Select an object..."
textBox.Parent = scrollingFrame

-- ==============================================================================
-- REFLECTION LOGIC (API Dump)
-- ==============================================================================

local function loadApiDump()
	if cachedApiDump then return true end

	textBox.Text = "Fetching API Dump..."
	task.wait(0.1)

	-- FIX: Check if we are in a Play Test on the Client, use RemoteFunction if true
	if RunService:IsClient() and not RunService:IsEdit() then
		local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME, 3)
		if remote then
			textBox.Text = "Fetching API Dump from Server via RemoteFunction..."
			local success, result = pcall(function()
				return remote:InvokeServer()
			end)

			if success and result then
				local decodeSuccess, decoded = pcall(function()
					return HttpService:JSONDecode(result)
				end)
				if decodeSuccess then
					cachedApiDump = decoded
					return true
				end
			end
		end

		textBox.Text = "Error: Could not fetch API Dump via RemoteFunction on the Client."
		return false
	end

	-- If on the Server or in standard Edit mode, use HttpService directly
	local success, result = pcall(function()
		return HttpService:GetAsync(API_DUMP_URL)
	end)

	if success then
		local decodeSuccess, decoded = pcall(function()
			return HttpService:JSONDecode(result)
		end)
		if decodeSuccess then
			cachedApiDump = decoded
			return true
		end
	end

	textBox.Text = "Error: Could not fetch API Dump.\nPlease enable 'Allow HTTP Requests' in Game Settings.\nDetails: " .. tostring(result)
	return false
end

local function getPropertiesForClass(className)
	if classPropertyCache[className] then
		return classPropertyCache[className]
	end

	if not cachedApiDump then return {} end

	local properties = {}
	local currentClass = className

	while currentClass do
		local classDef = nil
		for _, class in ipairs(cachedApiDump.Classes) do
			if class.Name == currentClass then
				classDef = class
				break
			end
		end

		if classDef then
			for _, member in ipairs(classDef.Members) do
				if member.MemberType == "Property" then
					local canRead = true
					if member.Tags then
						for _, tag in ipairs(member.Tags) do
							if tag == "Deprecated" or tag == "NotScriptable" or tag == "Hidden" then
								canRead = false
								break
							end
						end
					end
					if member.Security and member.Security.Read ~= "None" then
						canRead = false
					end

					if canRead then
						table.insert(properties, member.Name)
					end
				end
			end
			currentClass = classDef.Superclass
		else
			currentClass = nil
		end
	end

	table.sort(properties)
	classPropertyCache[className] = properties
	return properties
end

-- ==============================================================================
-- DATA GENERATION
-- ==============================================================================

local function getHierarchyString(instance, depth)
	local result = ""
	local indent = string.rep("    ", depth)
	local detailIndent = indent .. "  "

	result = result .. indent .. "[" .. instance.ClassName .. "] " .. instance.Name .. "\n"

	local tags = CollectionService:GetTags(instance)
	if #tags > 0 then
		result = result .. detailIndent .. "Tags: " .. table.concat(tags, ", ") .. "\n"
	end

	local attributes = instance:GetAttributes()
	local hasAttributes = false
	for name, value in pairs(attributes) do
		if not hasAttributes then
			result = result .. detailIndent .. "Attributes:\n"
			hasAttributes = true
		end
		result = result .. detailIndent .. "  • " .. name .. ": " .. tostring(value) .. "\n"
	end

	if SHOW_PROPERTIES then
		local propList = getPropertiesForClass(instance.ClassName)
		if #propList > 0 then
			result = result .. detailIndent .. "Properties:\n"
			for _, propName in ipairs(propList) do
				local success, val = pcall(function() return instance[propName] end)
				if success then
					local valStr = tostring(val)
					if #valStr > 50 then valStr = string.sub(valStr, 1, 47) .. "..." end
					result = result .. detailIndent .. "  • " .. propName .. ": " .. valStr .. "\n"
				end
			end
		end
	end

	for _, child in ipairs(instance:GetChildren()) do
		result = result .. getHierarchyString(child, depth + 1)
	end

	return result
end

local function updateInfo()
	local selected = Selection:Get()

	if #selected == 0 then
		textBox.Text = "No instances selected."
		return
	end

	if SHOW_PROPERTIES and not cachedApiDump then
		local success = loadApiDump()
		if not success then return end 
	end

	local fullText = ""
	for i, obj in ipairs(selected) do
		fullText = fullText .. "--- SELECTION " .. i .. " ---\n"
		fullText = fullText .. "Name: " .. obj.Name .. "\n"
		fullText = fullText .. "Class: " .. obj.ClassName .. "\n"
		fullText = fullText .. "Path: " .. obj:GetFullName() .. "\n"
		fullText = fullText .. "\nHIERARCHY:\n"
		fullText = fullText .. getHierarchyString(obj, 0)
		fullText = fullText .. "\n" .. string.rep("-", 30) .. "\n\n"
	end

	textBox.Text = fullText
end

-- ==============================================================================
-- EVENTS
-- ==============================================================================

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

propCheckbox.MouseButton1Click:Connect(function()
	SHOW_PROPERTIES = not SHOW_PROPERTIES

	if SHOW_PROPERTIES then
		propCheckbox.Text = "[X] Show Properties"
		updateInfo()
	else
		propCheckbox.Text = "[ ] Show Properties"
		updateInfo()
	end
end)

Selection.SelectionChanged:Connect(function()
	if widget.Enabled then
		updateInfo()
	end
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled then
		updateInfo()
	end
end)