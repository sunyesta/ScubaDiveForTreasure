--!strict
--[[
    ValueTester.lua
    A module for visualizing and modifying numeric variables in real-time.
    Supports automatic Server-to-Client networking for shared variables.
--]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Comm = require(ReplicatedStorage.Packages.Comm)
local Trove = require(ReplicatedStorage.Packages.Trove)

local GuiSlider
if RunService:IsClient() then
	GuiSlider = require(ReplicatedStorage.NonWallyPackages.GuiSlider)
end

local isServer = RunService:IsServer()
local COMM_NAMESPACE = "ValueTesterComm"

export type ValueTester = {
	Name: string,
	Min: number,
	Max: number,
	Value: any, -- Property Object
	Changed: any, -- Signal Object
	Destroy: (self: ValueTester) -> (),
	_trove: any,
}

local ValueTester = {}
ValueTester.__index = ValueTester

-- Store active network testers
local activeServerTesters = {}

-- Networking Variables
local comm
local updateSignal
local announceSignal
local valueChangedSignal
local getTestersFunc

-- Initialize Networking based on environment
if isServer then
	local ServerComm = Comm.ServerComm
	comm = ServerComm.new(ReplicatedStorage, COMM_NAMESPACE)

	updateSignal = comm:CreateSignal("UpdateValue")
	announceSignal = comm:CreateSignal("AnnounceTester")
	valueChangedSignal = comm:CreateSignal("ValueChanged")

	-- Allow new clients to fetch all existing server variables upon joining
	comm:BindFunction("GetTesters", function(player)
		local pack = {}
		for name, data in pairs(activeServerTesters) do
			pack[name] = { default = data.prop:Get(), min = data.min, max = data.max }
		end
		return pack
	end)

	-- Listen for client-driven slider updates
	updateSignal:Connect(function(player, name, val)
		if activeServerTesters[name] then
			activeServerTesters[name].prop:Set(val)
		end
	end)
else
	local commBuilt = false
	task.delay(5, function()
		if not commBuilt then
			warn(
				"[ValueTester] Client Comm isn't built after 5 seconds! Make sure the module is also required on the Server."
			)
		end
	end)

	local ClientComm = Comm.ClientComm
	comm = ClientComm.new(ReplicatedStorage, true, COMM_NAMESPACE)

	local obj = comm:BuildObject()
	updateSignal = obj.UpdateValue
	announceSignal = obj.AnnounceTester
	valueChangedSignal = obj.ValueChanged
	getTestersFunc = comm:GetFunction("GetTesters")

	commBuilt = true
end

-- Client-side UI State
local isGuiInitialized = false
local sliderContainer: ScrollingFrame? = nil

--// Helper: UI Generation (Client Only)
local function CreateSliderUI(
	name: string,
	default: number,
	min: number,
	max: number,
	isServerVar: boolean,
	targetProp: any
)
	if not isServer and not isGuiInitialized then
		ValueTester._initClientGui()
	end

	if not sliderContainer then
		return
	end

	-- Entry Container
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(1, 0, 0, 60)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 6)
	uiCorner.Parent = frame

	-- Label (Name + Scope)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 20)
	label.Position = UDim2.new(0, 10, 0, 5)
	label.BackgroundTransparency = 1
	label.Text = string.format("%s %s", isServerVar and "[Server]" or "[Client]", name)
	label.TextColor3 = isServerVar and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(150, 255, 150)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	-- Value Display
	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 50, 0, 20)
	valLabel.Position = UDim2.new(1, -60, 0, 5)
	valLabel.BackgroundTransparency = 1
	valLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valLabel.Font = Enum.Font.GothamMedium
	valLabel.TextSize = 14
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.Parent = frame

	-- Slider Bar (Must be ImageButton for GuiSlider)
	local bar = Instance.new("ImageButton")
	bar.Size = UDim2.new(1, -20, 0, 6)
	bar.Position = UDim2.new(0, 10, 1, -15)
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	bar.Image = ""
	bar.AutoButtonColor = false

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	bar.Parent = frame

	-- Slider Handle
	local handle = Instance.new("ImageButton")
	handle.Size = UDim2.new(0, 16, 0, 16)
	handle.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
	handle.Image = ""

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(1, 0)
	handleCorner.Parent = handle
	handle.Parent = bar

	-- Configure GuiSlider
	local slider = GuiSlider.new({
		Bar = bar,
		Handle = handle,
		Direction = GuiSlider.Directions.Horizontal,
		MinValue = min,
		MaxValue = max,
		DefaultValue = default,
	})

	-- Sync Logic
	slider._Trove:Add(slider.Value:Observe(function(val)
		valLabel.Text = string.format("%.2f", val)
		if targetProp:Get() ~= val then
			targetProp:Set(val)
			if isServerVar then
				-- Replicate change back to the server
				updateSignal:Fire(name, val)
			end
		end
	end))

	if isServerVar then
		targetProp:Observe(function(val)
			if slider.Value:Get() ~= val then
				slider.Value:Set(val)
			end
		end)
	end

	frame.Parent = sliderContainer
end

--// Helper: Initialize Client UI (Client Only)
function ValueTester._initClientGui()
	if isServer or isGuiInitialized then
		return
	end
	isGuiInitialized = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local sg = Instance.new("ScreenGui")
	sg.Name = "ValueTesterGui"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local container = Instance.new("ScrollingFrame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 300, 0, 400)
	container.Position = UDim2.new(0, 20, 0, 20)
	container.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	container.BackgroundTransparency = 0.1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 6

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = container

	container.Parent = sg
	sg.Parent = playerGui
	sliderContainer = container

	-- Fetch pre-existing Server variables
	getTestersFunc():andThen(function(testers)
		for name, data in pairs(testers) do
			if not activeServerTesters[name] then
				local proxyProp = Property.new(data.default)
				activeServerTesters[name] = { prop = proxyProp }
				CreateSliderUI(name, data.default, data.min, data.max, true, proxyProp)
			end
		end
	end)

	-- Listen for dynamically created Server variables
	announceSignal:Connect(function(name, def, min, max)
		if not activeServerTesters[name] then
			local proxyProp = Property.new(def)
			activeServerTesters[name] = { prop = proxyProp }
			CreateSliderUI(name, def, min, max, true, proxyProp)
		end
	end)

	-- Listen for value changes from the Server (or other clients via Server)
	valueChangedSignal:Connect(function(name, val)
		if activeServerTesters[name] then
			activeServerTesters[name].prop:Set(val)
		end
	end)
end

--// Public API
function ValueTester.new(name: string, default: number, min: number, max: number): any
	local self = setmetatable({}, ValueTester)
	self._trove = Trove.new()
	self.Name = name
	self.Min = min
	self.Max = max

	local prop = Property.new(default)
	self.Value = prop
	self.Changed = prop.Changed

	if isServer then
		activeServerTesters[name] = { prop = prop, min = min, max = max }

		-- Broadcast changes to all clients
		self._trove:Add(prop:Observe(function(val)
			valueChangedSignal:FireAll(name, val)
		end))

		-- Announce to current clients
		announceSignal:FireAll(name, default, min, max)
	else
		-- Create a local UI element
		CreateSliderUI(name, default, min, max, false, prop)
	end

	return prop
end

function ValueTester:Destroy()
	if isServer then
		activeServerTesters[self.Name] = nil
	end
	self._trove:Destroy()
end

return ValueTester
