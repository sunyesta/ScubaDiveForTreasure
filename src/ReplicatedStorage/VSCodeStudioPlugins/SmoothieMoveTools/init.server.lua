local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local PluginBehavior = require(script.PluginBehavior)
local GuiSlider = require(script.PluginGuiSlider)
local Property = require(script.PropertyLite)

local pluginName = "Smoothie"
local toolbar = plugin:CreateToolbar(pluginName)

local pluginButton = toolbar:CreateButton("Start", "Start Smoothie Move Tools", "rbxassetid://1852132956")

local info = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Bottom,
	false, -- Widget will be initially enabled
	false, -- Don't override previous enabled state
	200, -- default width
	300, -- default height
	150, -- minimum width
	150 -- minimum height
)

local widget = plugin:CreateDockWidgetPluginGui("SmoothieMoveToolsWidget", info)
widget.Title = pluginName

local guiBase = if script:FindFirstChild("MainFrame")
	then script.MainFrame.ContentFrame:Clone()
	else ReplicatedStorage.TemporaryStudioPlugins.SmoothieMoveTools.MainFrame.ContentFrame:Clone()
guiBase.Parent = widget

local gui = guiBase.AnchorFrame

local function setupColorSliders(trove)
	local selectedParts = {}
	local activeColor = Property.new(Color3.new())

	local function updateSelectedParts()
		local selected = Selection:Get()

		local newSelectedParts = {}
		for _, inst in selected do
			if inst:IsA("BasePart") then
				table.insert(newSelectedParts, inst)
			end
		end

		-- update activePart
		if #newSelectedParts > 0 then
			local activePart = newSelectedParts[#newSelectedParts]
			selectedParts = {}
			activeColor:Set(activePart.Color)
			selectedParts = newSelectedParts
		end
	end

	trove:Add(Selection.SelectionChanged:Connect(updateSelectedParts))

	trove:Add(activeColor.Changed:Connect(function(color)
		for _, part in selectedParts do
			part.Color = color
		end
	end))

	-- sliders
	local ColorBarsPage = gui.ColorBarsPage
	local HueSlider = trove:Add(GuiSlider.new(guiBase, {
		Bar = ColorBarsPage.HSVFrame.HueSlider,
		Handle = ColorBarsPage.HSVFrame.HueSlider.Handle,
		Direction = GuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	local SaturationSlider = trove:Add(GuiSlider.new(guiBase, {
		Bar = ColorBarsPage.HSVFrame.SaturationSlider,
		Handle = ColorBarsPage.HSVFrame.SaturationSlider.Handle,
		Direction = GuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	local ValueSlider = trove:Add(GuiSlider.new(guiBase, {
		Bar = ColorBarsPage.HSVFrame.ValueSlider,
		Handle = ColorBarsPage.HSVFrame.ValueSlider.Handle,
		Direction = GuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	local RedSlider = trove:Add(GuiSlider.new(guiBase, {
		Bar = ColorBarsPage.RGBFrame.RedSlider,
		Handle = ColorBarsPage.RGBFrame.RedSlider.Handle,
		Direction = GuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	local GreenSlider = trove:Add(GuiSlider.new(guiBase, {
		Bar = ColorBarsPage.RGBFrame.GreenSlider,
		Handle = ColorBarsPage.RGBFrame.GreenSlider.Handle,
		Direction = GuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	local BlueSlider = trove:Add(GuiSlider.new(guiBase, {
		Bar = ColorBarsPage.RGBFrame.BlueSlider,
		Handle = ColorBarsPage.RGBFrame.BlueSlider.Handle,
		Direction = GuiSlider.Directions.Horizontal,
		MinValue = 0,
		MaxValue = 1,
	}))

	local lastHue = 0
	local lastSaturation = 0
	trove:Add(activeColor:Observe(function(color)
		local h, s, v = color:ToHSV()
		local r, g, b = color.R, color.G, color.B

		h = if s == 0 then lastHue else h
		s = if v == 0 then lastSaturation else s
		lastHue = h
		lastSaturation = s

		HueSlider.Value:Set(h)
		SaturationSlider.Value:Set(s)
		ValueSlider.Value:Set(v)

		RedSlider.Value:Set(r)
		GreenSlider.Value:Set(g)
		BlueSlider.Value:Set(b)

		SaturationSlider.Bar.UIGradient.Color = ColorSequence.new(Color3.fromHSV(h, 0, v), Color3.fromHSV(h, 1, v))
		ValueSlider.Bar.UIGradient.Color = ColorSequence.new(Color3.fromHSV(h, s, 0), Color3.fromHSV(h, s, 1))

		RedSlider.Bar.UIGradient.Color = ColorSequence.new(Color3.new(0, g, b), Color3.new(1, g, b))
		GreenSlider.Bar.UIGradient.Color = ColorSequence.new(Color3.new(r, 0, b), Color3.new(r, 1, b))
		BlueSlider.Bar.UIGradient.Color = ColorSequence.new(Color3.new(r, g, 0), Color3.new(r, g, 1))
	end))

	trove:Add(HueSlider.Dragged:Connect(function()
		activeColor:Set(Color3.fromHSV(HueSlider.Value:Get(), SaturationSlider.Value:Get(), ValueSlider.Value:Get()))
	end))

	trove:Add(SaturationSlider.Dragged:Connect(function()
		activeColor:Set(Color3.fromHSV(HueSlider.Value:Get(), SaturationSlider.Value:Get(), ValueSlider.Value:Get()))
	end))

	trove:Add(ValueSlider.Dragged:Connect(function()
		activeColor:Set(Color3.fromHSV(HueSlider.Value:Get(), SaturationSlider.Value:Get(), ValueSlider.Value:Get()))
	end))

	trove:Add(RedSlider.Dragged:Connect(function()
		activeColor:Set(Color3.new(RedSlider.Value:Get(), GreenSlider.Value:Get(), BlueSlider.Value:Get()))
	end))

	trove:Add(GreenSlider.Dragged:Connect(function()
		activeColor:Set(Color3.new(RedSlider.Value:Get(), GreenSlider.Value:Get(), BlueSlider.Value:Get()))
	end))

	trove:Add(BlueSlider.Dragged:Connect(function()
		activeColor:Set(Color3.new(RedSlider.Value:Get(), GreenSlider.Value:Get(), BlueSlider.Value:Get()))
	end))
end

local function newPluginBehavior()
	local offColor = Color3.fromHex("#545454")
	local onColor = Color3.fromHex("#2bb1ff")

	local trove = Trove.new()
	local pluginBehavior = trove:Add(PluginBehavior.new())

	-- Snap Toggle
	trove:Add(pluginBehavior.Config.Snapping:Observe(function(snapping)
		gui.SnapFrame.SnapSwitch.BackgroundColor3 = if snapping then onColor else offColor
	end))

	trove:Add(gui.SnapFrame.SnapSwitch.MouseButton1Click:Connect(function()
		pluginBehavior.Config.Snapping:Set(not pluginBehavior.Config.Snapping:Get())
	end))

	-- Rotate Toggle
	trove:Add(pluginBehavior.Config.SnapRotate:Observe(function(snapRotate)
		gui.SnapFrame.RotateSwitch.BackgroundColor3 = if snapRotate then onColor else offColor
	end))

	trove:Add(gui.SnapFrame.RotateSwitch.MouseButton1Click:Connect(function()
		pluginBehavior.Config.SnapRotate:Set(not pluginBehavior.Config.SnapRotate:Get())
	end))

	local axisSelector = gui.AxisSelector
	trove:Add(axisSelector.GlobalButton.MouseButton1Click:Connect(function()
		pluginBehavior.Config.AxisMode:Set(pluginBehavior.Enum.Axis.Global)
	end))

	trove:Add(axisSelector.LocalButton.MouseButton1Click:Connect(function()
		pluginBehavior.Config.AxisMode:Set(pluginBehavior.Enum.Axis.Local)
	end))

	trove:Add(axisSelector.ViewButton.MouseButton1Click:Connect(function()
		pluginBehavior.Config.AxisMode:Set(pluginBehavior.Enum.Axis.View)
	end))

	pluginBehavior.Config.AxisMode:Observe(function(axisMode)
		local axisSelectionHighlight = axisSelector.SelectionHighlight
		if axisMode == pluginBehavior.Enum.Axis.Global then
			axisSelectionHighlight.Position = UDim2.fromScale(0, 0)
		elseif axisMode == pluginBehavior.Enum.Axis.Local then
			axisSelectionHighlight.Position = UDim2.fromScale(0.348, 0)
		elseif axisMode == pluginBehavior.Enum.Axis.View then
			axisSelectionHighlight.Position = UDim2.fromScale(0.652, 0)
		end
	end)

	-- Buttons
	trove:Add(gui.UpdateSAsButton.MouseButton1Click:Connect(function()
		pluginBehavior:UpdateSurfaceAppearances()
	end))

	trove:Add(gui.CopySAToSelectedButton.MouseButton1Click:Connect(function()
		pluginBehavior:CopySAToSelected()
	end))

	-- setupColorSliders(trove)

	return trove
end

local activeTrove = Trove.new()
if widget.Enabled then
	pluginBehavior = activeTrove:Add(newPluginBehavior())
end

pluginButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	if widget.Enabled then
		activeTrove:Add(newPluginBehavior())
	else
		activeTrove:Clean()
	end
end)

plugin.Unloading:Connect(function()
	activeTrove:Clean()
end)
