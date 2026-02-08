local LogService = game:GetService("LogService")

local ConsoleVisualizer = {}
ConsoleVisualizer.__index = ConsoleVisualizer

-- Constants for styling
local FONT_SIZE = 14
local FONT = Enum.Font.Code
local COLORS = {
	[Enum.MessageType.MessageOutput] = Color3.fromRGB(255, 255, 255),
	[Enum.MessageType.MessageInfo] = Color3.fromRGB(170, 204, 255),
	[Enum.MessageType.MessageWarning] = Color3.fromRGB(255, 170, 0),
	[Enum.MessageType.MessageError] = Color3.fromRGB(255, 85, 85),
}

function ConsoleVisualizer.new(parent)
	local self = setmetatable({}, ConsoleVisualizer)

	-- Create Main Scrolling Frame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "ConsoleVisualizer"
	scroller.Size = UDim2.new(1, 0, 1, 0)
	scroller.Position = UDim2.new(0, 0, 0, 0)
	scroller.BackgroundTransparency = 0.5
	scroller.BackgroundColor3 = Color3.new(0, 0, 0)
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 8
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Parent = scroller
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)

	local padding = Instance.new("UIPadding")
	padding.Parent = scroller
	padding.PaddingLeft = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 5)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)

	self._gui = scroller
	self._connections = {}

	-- Connect to existing logs
	table.insert(
		self._connections,
		LogService.MessageOut:Connect(function(message, messageType)
			self:Log(message, messageType)
		end)
	)

	return self
end

function ConsoleVisualizer:Log(message, messageType)
	if not self._gui then
		return
	end

	local label = Instance.new("TextLabel")
	label.Text = message
	label.TextColor3 = COLORS[messageType] or COLORS[Enum.MessageType.MessageOutput]
	label.Font = FONT
	label.TextSize = FONT_SIZE
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true

	-- Size handling
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y

	label.Parent = self._gui

	-- Auto-scroll to bottom
	-- We defer slightly to ensure the layout has updated the AbsoluteCanvasSize
	task.defer(function()
		if self._gui then
			self._gui.CanvasPosition = Vector2.new(0, self._gui.AbsoluteCanvasSize.Y)
		end
	end)
end

function ConsoleVisualizer:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}

	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

return ConsoleVisualizer
