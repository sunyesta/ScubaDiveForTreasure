local UserInputService = game:GetService("UserInputService")
local Selection = game:GetService("Selection")

local Props = require(script.Parent.Props)
local Enums = require(script.Parent.Enums)

local ExtraBehavior = {}

function ExtraBehavior.Init(plugin, pluginTrove)
	-- Dictionary to keep track of objects and their original parents
	-- Format: { [Instance] = ParentInstance }
	local hiddenObjects = {}

	-- State to keep track of the temporary snapping toggle
	local isCtrlHeld = false
	local preCtrlSnappingState = false

	-- Helper function to restore all hidden objects back to their parents
	local function restoreHiddenObjects()
		for obj, originalParent in pairs(hiddenObjects) do
			-- Ensure the object wasn't destroyed while hidden
			if obj and originalParent then
				obj.Parent = originalParent
			end
		end
		-- Clear the dictionary after restoring
		table.clear(hiddenObjects)
	end

	-- 1. If the plugin trove is cleaned (plugin deactivated/updated), restore objects automatically!
	pluginTrove:Add(restoreHiddenObjects)

	-- Handle Key Presses
	local function onInputBegan(input, gameProcessedEvent)
		-- We ignore gameProcessedEvent for plugins sometimes, but it's good practice to include it
		-- However, in a plugin viewport, we usually want to catch the input anyway.

		-- Ctrl for temporarily inverting Snapping state (Holding down)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			if not isCtrlHeld then
				isCtrlHeld = true
				preCtrlSnappingState = Props.UseSnapping:Get()
				Props.UseSnapping:Set(not preCtrlSnappingState)
			end
		end

		-- H for Hiding / Alt+H for Unhiding
		if input.KeyCode == Enum.KeyCode.H then
			-- Check if either Alt key is currently being held down
			local isAltDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)

			if isAltDown then
				-- Alt + H was pressed: Unhide
				restoreHiddenObjects()
			else
				-- Just H was pressed: Hide selected objects
				local selected = Props.SelectedObjects:Get()

				for _, obj in ipairs(selected) do
					if obj.Parent ~= nil then
						-- Save the parent before hiding
						hiddenObjects[obj] = obj.Parent
						-- Parent to nil to hide it from the Workspace/Explorer
						obj.Parent = nil
					end
				end

				-- Optional but recommended: Clear the current selection so Roblox Studio
				-- draggers don't bug out trying to move objects that are parented to nil.
				Props.SelectedObjects:Set({})
				Selection:Set({})
			end
		end
	end

	-- Handle Key Releases
	local function onInputEnded(input, gameProcessedEvent)
		-- Ctrl release to restore Snapping state
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			-- Ensure the user isn't holding the *other* control key before setting back
			local leftCtrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			local rightCtrl = UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

			if not leftCtrl and not rightCtrl then
				if isCtrlHeld then
					isCtrlHeld = false
					Props.UseSnapping:Set(preCtrlSnappingState)
				end
			end
		end
	end

	-- Connect our input events
	local inputBeganConn = UserInputService.InputBegan:Connect(onInputBegan)
	local inputEndedConn = UserInputService.InputEnded:Connect(onInputEnded)

	-- 2. Add the connections to the Trove so they are disconnected when the plugin stops
	pluginTrove:Add(inputBeganConn)
	pluginTrove:Add(inputEndedConn)
end

return ExtraBehavior
