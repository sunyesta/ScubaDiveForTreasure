local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

-- Assume these packages exist in your project structure
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)
local Input = require(ReplicatedStorage.Packages.Input)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local GuiUtils = require(ReplicatedStorage.NonWallyPackages.GuiUtils)
local PlayerModule = require(Players.LocalPlayer.PlayerScripts.PlayerModule)

local Touch = Input.Touch.new()

-- Multi Touch
local MultiTouch = {}
MultiTouch.__index = MultiTouch

local TouchType = {
	Gui = "Gui",
	Thumbstick = "Thumbstick",
	Unprocessed = "Unprocessed",
}

MultiTouch.TouchType = TouchType

local function GetThumbstickFrame()
	if PlayerModule and PlayerModule.controls and PlayerModule.controls.activeController then
		return PlayerModule.controls.activeController.thumbstickFrame
	end
	return nil
end

-- Helper function to apply the dynamic offset
local function GetCorrectedPosition(position: Vector3)
	local inset = GuiService:GetGuiInset()
	return Vector2.new(position.X, position.Y + inset.Y)
end

function MultiTouch:FilterTouchPositions(touchPositions, whitelist)
	local filtered = {}
	for id, data in pairs(touchPositions) do
		local touchType = data.TouchType
		local position = data.Position

		if
			(touchType == TouchType.Gui and whitelist.Gui)
			or (touchType == TouchType.Thumbstick and whitelist.Thumbstick)
			or (touchType == TouchType.Unprocessed and whitelist.Unprocessed)
		then
			filtered[id] = position
		end
	end
	return filtered
end

function MultiTouch.new()
	local self = setmetatable({}, MultiTouch)
	self._Trove = Trove.new()
	self.TouchPositions = Property.new({})

	-- Debugging Property
	self.ViewTouchPositions = false

	-- Internal State
	self._NextId = 0
	self._TouchMap = {} -- [InputObject] = ID
	self._Visualizers = {} -- [ID] = Frame
	self._VisualizerGui = nil

	self._Trove:Add(Touch.TouchStarted:Connect(function(touch, processed)
		local touchType = if processed then TouchType.Gui else TouchType.Unprocessed

		local thumbstickFrame = GetThumbstickFrame()

		if thumbstickFrame ~= nil and GuiUtils.PointInGui(thumbstickFrame, touch.Position) then
			touchType = TouchType.Thumbstick
		end

		-- Generate unique ID and map it to the input object
		self._NextId += 1
		local id = self._NextId
		self._TouchMap[touch] = id

		local correctedPos = GetCorrectedPosition(touch.Position)

		-- Use the helper to get position with dynamic offset
		local touchDatas = table.clone(self.TouchPositions:Get())
		touchDatas[id] = {
			TouchType = touchType,
			Position = correctedPos,
			ID = id,
		}
		self.TouchPositions:Set(touchDatas)

		-- Visualization
		if self.ViewTouchPositions then
			self:_UpdateVisualizer(id, correctedPos)
		end
	end))

	self._Trove:Add(Touch.TouchEnded:Connect(function(touch, processed)
		local id = self._TouchMap[touch]

		if id then
			local touchDatas = self.TouchPositions:Get()
			if touchDatas[id] then
				touchDatas = table.clone(touchDatas)
				touchDatas[id] = nil
				self.TouchPositions:Set(touchDatas)
			end

			-- Visualization Cleanup
			self:_RemoveVisualizer(id)

			-- Clean up map
			self._TouchMap[touch] = nil
		end
	end))

	self._Trove:Add(Touch.TouchMoved:Connect(function(touch)
		local id = self._TouchMap[touch]

		if id then
			local touchDatas = self.TouchPositions:Get()

			if touchDatas[id] then
				local currentData = touchDatas[id]
				local correctedPos = GetCorrectedPosition(touch.Position)

				touchDatas = table.clone(touchDatas)
				-- Update position while preserving Type and ID
				touchDatas[id] = {
					TouchType = currentData.TouchType,
					Position = correctedPos,
					ID = id,
				}
				self.TouchPositions:Set(touchDatas)

				-- Visualization Update
				if self.ViewTouchPositions then
					self:_UpdateVisualizer(id, correctedPos)
				else
					-- Cleanup if toggled off mid-touch
					self:_RemoveVisualizer(id)
				end
			end
		end
	end))

	return self
end

function MultiTouch:_GetVisualizerGui()
	if not self._VisualizerGui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "TouchVisualizers"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 10000

		if Players.LocalPlayer then
			gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		end

		self._VisualizerGui = gui
		self._Trove:Add(gui)
	end
	return self._VisualizerGui
end

function MultiTouch:_UpdateVisualizer(id, position)
	local gui = self:_GetVisualizerGui()
	local frame = self._Visualizers[id]

	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Touch_" .. id
		frame.Size = UDim2.fromOffset(60, 60)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		-- Random vibrant color for each touch
		frame.BackgroundColor3 = Color3.fromHSV(math.random(), 0.7, 1)
		frame.BackgroundTransparency = 0.4
		frame.BorderSizePixel = 0
		frame.Active = false

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = tostring(id)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.5
		label.TextSize = 24
		label.Font = Enum.Font.GothamBold
		label.Active = false
		label.Parent = frame

		frame.Parent = gui
		self._Visualizers[id] = frame
	end

	frame.Position = UDim2.fromOffset(position.X, position.Y)
end

function MultiTouch:_RemoveVisualizer(id)
	local frame = self._Visualizers[id]
	if frame then
		frame:Destroy()
		self._Visualizers[id] = nil
	end
end

function MultiTouch:Destroy()
	self._Trove:Clean()
end

-- Return the singleton instance
return MultiTouch.new()
