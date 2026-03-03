local Widget = require(script.Widget)
local Trove = require(script.Modules.Trove)

-- Create the Toolbar and Button
local toolbar = plugin:CreateToolbar("Random Studio Tools")
-- Arguments: ButtonId, Tooltip, Icon Asset ID
local toggleButton = toolbar:CreateButton(
	"RandomStudioTools",
	"RandomStudioTools",
	"rbxassetid://1507949215" -- Replace with your own icon asset ID
)
toggleButton.ClickableWhenViewportHidden = true

local pluginTrove = nil
local isEnabled = false

-- Disables the plugin and cleans up all memory/connections
local function disablePlugin()
	if not isEnabled then
		return
	end
	isEnabled = false
	toggleButton:SetActive(false)

	-- Clean all modules and UI
	if pluginTrove then
		pluginTrove:Clean()
		pluginTrove = nil
	end
end

-- Enables the plugin, creates the trove, and initializes all modules
local function enablePlugin()
	if isEnabled then
		return
	end
	isEnabled = true
	toggleButton:SetActive(true)

	-- Create a master trove for this specific plugin session
	pluginTrove = Trove.new()

	-- We now receive the returned widget to properly track it
	local gui = Widget.Init(plugin, pluginTrove)

	-- Ensure gui is not nil before trying to attach connections
	if gui then
		-- Listen to the 'Enabled' property. If the user clicks the "X" button to close it manually,
		-- we disable the plugin to keep the Toolbar button synced.
		pluginTrove:Add(gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not gui.Enabled then
				disablePlugin()
			end
		end))
	else
		warn(
			"[Smoothie Move Tools] Warning: Widget.Init did not return the GUI. Make sure Widget.Init in Widget.lua ends with 'return gui'"
		)
	end
end

-- Toggle the plugin state when the toolbar button is clicked
toggleButton.Click:Connect(function()
	if isEnabled then
		disablePlugin()
	else
		enablePlugin()
	end
end)

-- Ensure we clean up everything when the plugin unloads or is updated
plugin.Unloading:Connect(function()
	disablePlugin()
end)
