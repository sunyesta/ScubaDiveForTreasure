local Trove = require(script.Parent.Trove)
local Signal = require(script.Parent.Signal)
local UserInputService = game:GetService("UserInputService")

local WidgetMouse = {}
WidgetMouse.__index = WidgetMouse

function WidgetMouse.new(gui: GuiObject | DockWidgetPluginGui)
	local self = setmetatable({}, WidgetMouse)
	self._gui = gui
	self._Trove = Trove.new()
	self.X = 0
	self.Y = 0
	self.Moved = Signal.new()

	-- Fix: Connect to UserInputService globally instead of the restricted Widget event
	self._Trove:Add(UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- Check if it's a plugin widget to accurately get the relative position
			if self._gui:IsA("DockWidgetPluginGui") then
				local relativePos = self._gui:GetRelativeMousePosition()
				self.X = relativePos.X
				self.Y = relativePos.Y
			else
				self.X = input.Position.X
				self.Y = input.Position.Y
			end

			self.Moved:Fire()
		end
	end))

	return self
end

function WidgetMouse:GetPosition(): Vector2
	return Vector2.new(self.X, self.Y)
end

function WidgetMouse:Destroy()
	self._Trove:Clean()
end

function WidgetMouse:IsLeftDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

function WidgetMouse:IsRightDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

function WidgetMouse:IsMiddleDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
end

return WidgetMouse
