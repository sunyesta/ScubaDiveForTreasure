--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

local Props = require(script.Parent.Props)

local ColorBehavior = {}

-- Store the main plugin trove so our local tools can access it and bind to its lifecycle
local moduleTrove: any = nil

-- Initiates the reactive listeners for coloring behavior
function ColorBehavior.Init(plugin: Plugin, pluginTrove: any): ()
	moduleTrove = pluginTrove

	-- We use a flag to track if we are just syncing the UI vs actually picking a new color
	local isSyncingColor = false

	-- We add a startup flag to prevent the default state from overwriting parts on load
	local isInitializing = true

	-- 1. Observe when the ActivePart changes and bind it to the main Trove
	pluginTrove:Add(Props.ActivePart:Observe(function(newActivePart: Instance?)
		if newActivePart and newActivePart:IsA("BasePart") then
			isSyncingColor = true
			Props.ActiveColor:Set(newActivePart.Color)
			isSyncingColor = false
		end
	end))

	-- 2. Observe when the ActiveColor changes and bind it to the main Trove
	pluginTrove:Add(Props.ActiveColor:Observe(function(newColor: Color3)
		if isSyncingColor or isInitializing then
			return
		end

		local selectedObjects: { Instance } = Props.SelectedObjects:Get()

		if selectedObjects then
			for _, object in ipairs(selectedObjects) do
				if object:IsA("BasePart") then
					object.Color = newColor
				end
			end
		end
	end))

	isInitializing = false
end

-- Validates that the current selection only contains colorable parts
function ColorBehavior.ValidateSelectionForColoring(): (boolean, string?)
	local selectedObjects: { Instance } = Props.SelectedObjects:Get()

	if not selectedObjects or #selectedObjects == 0 then
		return false, "nothing is selected"
	end

	for _, object in ipairs(selectedObjects) do
		if not object:IsA("BasePart") then
			return false, "you can only color baseparts"
		end
	end

	return true, nil
end

-- Activates the Eyedropper tool to pick a color from the Workspace
function ColorBehavior.StartEyedropperTool(plugin: Plugin)
	assert(moduleTrove, "ColorBehavior.Init() must be called with a Trove before using the Eyedropper tool!")

	local previousTool = plugin:GetSelectedRibbonTool()
	local originalSelection = Selection:Get()
	local pickedSuccessfully = false

	plugin:Activate(true)
	UserInputService.MouseIconEnabled = false

	-- Create a sub-trove. If the main plugin closes, this tool sub-trove is destroyed automatically!
	local toolTrove = moduleTrove:Extend()

	-- Setup Visuals (UI Cursor) bound to the toolTrove
	local screenGui = toolTrove:Add(Instance.new("ScreenGui"))
	screenGui.Name = "EyedropperCursorGui"
	screenGui.Parent = CoreGui

	local cursorImage = Instance.new("ImageLabel")
	cursorImage.Name = "Cursor"
	cursorImage.Image = "rbxassetid://126362121736567"
	cursorImage.BackgroundTransparency = 1
	cursorImage.Size = UDim2.fromOffset(20, 20)
	cursorImage.ScaleType = Enum.ScaleType.Fit
	cursorImage.Parent = screenGui

	-- Setup Visuals (Highlight) bound to the toolTrove
	local highlight = toolTrove:Add(Instance.new("Highlight"))
	highlight.Name = "EyedropperHighlight"
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = CoreGui

	-- Add custom state restoration logic to the Trove.
	-- This executes safely when toolTrove:Destroy() is called.
	toolTrove:Add(function()
		UserInputService.MouseIconEnabled = true
		plugin:Deactivate()

		if not pickedSuccessfully then
			Selection:Set(originalSelection)
		end

		local currentTool = plugin:GetSelectedRibbonTool()
		if currentTool == Enum.RibbonTool.Select or currentTool == Enum.RibbonTool.None or pickedSuccessfully then
			pcall(function()
				plugin:SelectRibbonTool(previousTool)
			end)
		end
	end)

	local activeHoverPart: BasePart? = nil
	local camera = Workspace.CurrentCamera

	-- Update Loop (Hover Logic & Cursor Follow)
	-- toolTrove:Connect automatically disconnects the event on cleanup
	toolTrove:Connect(RunService.RenderStepped, function()
		local mouseLocation = UserInputService:GetMouseLocation()
		cursorImage.Position = UDim2.fromOffset(mouseLocation.X + 20, mouseLocation.Y + 20)

		if camera then
			local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = { screenGui }

			local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

			if result and result.Instance and result.Instance:IsA("BasePart") then
				activeHoverPart = result.Instance
				highlight.Adornee = activeHoverPart
				highlight.FillColor = activeHoverPart.Color
				highlight.Enabled = true
			else
				activeHoverPart = nil
				highlight.Adornee = nil
				highlight.Enabled = false
			end
		end
	end)

	-- Input Loop (Clicking confirmation)
	toolTrove:Connect(UserInputService.InputBegan, function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if activeHoverPart then
				pickedSuccessfully = true
				Props.ActiveColor:Set(activeHoverPart.Color)

				-- Destroys the UI, disconnects all events, and runs our custom cleanup function
				toolTrove:Destroy()
			end
		end
	end)

	-- Detect Escape key by listening for Studio natively clearing the Selection
	toolTrove:Connect(Selection.SelectionChanged, function()
		local currentSelection = Selection:Get()
		if #currentSelection == 0 then
			toolTrove:Destroy()
		end
	end)

	-- Deactivation fallback just in case the user selects another plugin entirely
	toolTrove:Connect(plugin.Deactivation, function()
		toolTrove:Destroy()
	end)
end

return ColorBehavior
