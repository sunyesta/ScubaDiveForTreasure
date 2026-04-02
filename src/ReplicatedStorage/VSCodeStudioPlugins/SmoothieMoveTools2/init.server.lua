local Widget = require(script.Widget)
local Trove = require(script.Modules.Trove)
local SelectionBehavior = require(script.SelectionBehavior)
local ColorBehavior = require(script.ColorBehavior)
local GizmoBehavior = require(script.GizmoBehavior)
local MoveAndRotateBehavior = require(script.MoveAndRotateBehavior)
local ExtraBehavior = require(script.ExtraBehavior)

-- Create the Toolbar and Button
local toolbar = plugin:CreateToolbar("Smoothie Move Tools")
-- Arguments: ButtonId, Tooltip, Icon Asset ID
local toggleButton = toolbar:CreateButton(
	"Toggle Smoothie Move Tolls",
	"Toggle Smoothie Move Tools",
	"http://www.roblox.com/asset/?id=87600813209901" -- Replace with your own icon asset ID
)
toggleButton.ClickableWhenViewportHidden = true

local pluginTrove = nil
local isEnabled = false

-- Enables the plugin, creates the trove, and initializes all modules
local function enablePlugin()
	if isEnabled then
		return
	end
	isEnabled = true
	toggleButton:SetActive(true)

	-- Create a master trove for this specific plugin session
	pluginTrove = Trove.new()

	-- Initialize modules. We capture the returned widget so we can track its 'Enabled' state
	local pluginGui = Widget.Init(plugin, pluginTrove)
	SelectionBehavior.Init(plugin, pluginTrove)
	ColorBehavior.Init(plugin, pluginTrove)
	GizmoBehavior.Init(plugin, pluginTrove)
	MoveAndRotateBehavior.Init(plugin, pluginTrove)
	ExtraBehavior.Init(plugin, pluginTrove)

	-- If the user clicks the "X" on the widget to close it, clean up everything
	if pluginGui then
		pluginTrove:Add(pluginGui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not pluginGui.Enabled and isEnabled then
				-- We must disable the plugin to clean the troves and deselect the button
				disablePlugin()
			end
		end))
	end
end

-- Disables the plugin and cleans up all memory/connections
function disablePlugin()
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
