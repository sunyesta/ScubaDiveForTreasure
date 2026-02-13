local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local WidgetMouse = {}
WidgetMouse.__index = WidgetMouse

function WidgetMouse.new(gui)
	local self = setmetatable({}, WidgetMouse)
	self._gui = gui
	self._Trove = Trove.new()
	self.X = 0
	self.Y = 0
	self.Moved = Signal.new()

	-- Connect input events to update mouse position
	self._Trove:Add(gui.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self.X = input.Position.X
			self.Y = input.Position.Y
			self.Moved:Fire()
		end
	end))

	return self
end

function WidgetMouse:GetPosition()
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
