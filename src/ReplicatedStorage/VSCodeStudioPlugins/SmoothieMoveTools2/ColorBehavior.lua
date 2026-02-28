--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

local Props = require(script.Parent.Props)

local ColorBehavior = {}

-- Initiates the reactive listeners for coloring behavior
function ColorBehavior.Init(): ()
	-- We use a flag to track if we are just syncing the UI vs actually picking a new color
	local isSyncingColor = false

	-- 1. Observe when the ActivePart changes
	Props.ActivePart:Observe(function(newActivePart: Instance?)
		-- We check if it exists and is a BasePart (Part, MeshPart, Wedge, etc.)
		if newActivePart and newActivePart:IsA("BasePart") then
			-- Sync the ActiveColor state to match the newly selected part
			isSyncingColor = true
			Props.ActiveColor:Set(newActivePart.Color)
			isSyncingColor = false
		end
	end)

	-- 2. Observe when the ActiveColor changes
	Props.ActiveColor:Observe(function(newColor: Color3)
		-- If the color change was triggered by selecting a new part, ignore it!
		if isSyncingColor then
			return
		end

		-- Retrieve the current selection of objects instead of just the active part
		local selectedObjects: { Instance } = Props.SelectedObjects:Get()

		-- Make sure the selection table exists
		if selectedObjects then
			-- Loop through every object in the selection
			for _, object in ipairs(selectedObjects) do
				-- If the object is a BasePart, update its color to the new selection
				if object:IsA("BasePart") then
					object.Color = newColor
				end
			end
		end
	end)
end

-- Validates that the current selection only contains colorable parts
function ColorBehavior.ValidateSelectionForColoring(): (boolean, string?)
	-- Retrieve the current selection from our state manager
	local selectedObjects: { Instance } = Props.SelectedObjects:Get()

	-- If nothing is selected, we shouldn't consider it a valid selection for coloring
	if not selectedObjects or #selectedObjects == 0 then
		return false, "nothing is selected"
	end

	-- Loop through everything in the selection table
	for _, object in ipairs(selectedObjects) do
		-- If any object is NOT a BasePart (e.g., a Model, Folder, or Script), return false
		if not object:IsA("BasePart") then
			return false, "you can only color baseparts"
		end
	end

	-- If the loop finishes without returning false, all items are valid parts!
	return true, nil
end

-- Activates the Eyedropper tool to pick a color from the Workspace
function ColorBehavior.StartEyedropperTool(plugin: Plugin)
	-- Save the currently active Studio tool and the current selection
	local previousTool = plugin:GetSelectedRibbonTool()
	local originalSelection = Selection:Get()
	local pickedSuccessfully = false

	-- Activate the plugin to request exclusive mouse control from Studio
	plugin:Activate(true)

	-- Setup Visuals (UI Cursor)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EyedropperCursorGui"
	screenGui.Parent = CoreGui

	local cursorImage = Instance.new("ImageLabel")
	cursorImage.Name = "Cursor"
	cursorImage.Image = "rbxassetid://126362121736567"
	cursorImage.BackgroundTransparency = 1
	cursorImage.Size = UDim2.fromOffset(20, 20)
	cursorImage.ScaleType = Enum.ScaleType.Fit
	cursorImage.Parent = screenGui

	-- Setup Visuals (Highlight)
	local highlight = Instance.new("Highlight")
	highlight.Name = "EyedropperHighlight"
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = CoreGui

	-- Hide the default mouse cursor
	UserInputService.MouseIconEnabled = false

	-- State tracking for the tool
	local connections: { RBXScriptConnection } = {}
	local activeHoverPart: BasePart? = nil

	-- Flag to prevent cleanUp from running multiple times recursively
	local isCleaningUp = false

	-- Cleanup function to safely exit the tool and restore defaults
	local function cleanUp()
		-- Prevent this function from running twice
		if isCleaningUp then
			return
		end
		isCleaningUp = true

		-- Disconnect events FIRST so restoring the selection doesn't re-trigger SelectionChanged
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		table.clear(connections)

		if screenGui then
			screenGui:Destroy()
		end
		if highlight then
			highlight:Destroy()
		end

		UserInputService.MouseIconEnabled = true

		-- Deactivate the plugin state if it isn't already deactivated
		plugin:Deactivate()

		-- If the user cancelled (hit Escape), Studio naturally dropped the selection.
		-- We want to restore what they originally had selected!
		if not pickedSuccessfully then
			Selection:Set(originalSelection)
		end

		-- Restore the tool they had BEFORE clicking the Eyedropper.
		local currentTool = plugin:GetSelectedRibbonTool()
		if currentTool == Enum.RibbonTool.Select or currentTool == Enum.RibbonTool.None or pickedSuccessfully then
			pcall(function()
				plugin:SelectRibbonTool(previousTool)
			end)
		end
	end

	-- Update Loop (Hover Logic & Cursor Follow)
	local camera = Workspace.CurrentCamera
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local mouseLocation = UserInputService:GetMouseLocation()

			-- Offset by 20 pixels on the bottom right (X + 20, Y + 20)
			cursorImage.Position = UDim2.fromOffset(mouseLocation.X + 20, mouseLocation.Y + 20)

			-- Raycast to find parts under the mouse
			if camera then
				local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = { screenGui }

				local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

				-- Check if we hit a BasePart
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
	)

	-- Input Loop (Clicking confirmation)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				-- Selection Confirmation
				if activeHoverPart then
					pickedSuccessfully = true
					local pickedColor = activeHoverPart.Color

					-- Feed the picked color back into the state
					Props.ActiveColor:Set(pickedColor)

					-- Disable the tool after picking
					cleanUp()
				end
			end
		end)
	)

	-- Detect Escape key by listening for Studio natively clearing the Selection
	table.insert(
		connections,
		Selection.SelectionChanged:Connect(function()
			local currentSelection = Selection:Get()
			-- If the selection becomes completely empty, it means the user hit Escape or clicked into the void
			if #currentSelection == 0 then
				cleanUp()
			end
		end)
	)

	-- Keep Deactivation as a fallback just in case the user selects another plugin entirely
	table.insert(
		connections,
		plugin.Deactivation:Connect(function()
			cleanUp()
		end)
	)
end

return ColorBehavior
