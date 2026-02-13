local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local plugin = script:FindFirstAncestorOfClass("Plugin")
assert(plugin, "script not inside a plugin!")

plugin:Activate(true)
local Mouse = plugin:GetMouse()

local RAY_DISTANCE = 5000 -- Reduced from 100000 to be more reasonable

local PluginMouse = {}
PluginMouse.__index = setmetatable(PluginMouse, { __index = Mouse })

function PluginMouse.new()
	local self = setmetatable({}, PluginMouse)
	return self
end

PluginMouse.Mouse = Mouse

PluginMouse.LeftDown = Mouse.Button1Down
PluginMouse.LeftUp = Mouse.Button1Up
PluginMouse.RightDown = Mouse.Button2Down
PluginMouse.RightUp = Mouse.Button2Up
PluginMouse.Moved = Mouse.Move
PluginMouse.WheelBackward = Mouse.WheelBackward
PluginMouse.WheelForward = Mouse.WheelForward
PluginMouse.DragEnter = Mouse.DragEnter

function PluginMouse:GetPosition()
	return Vector2.new(Mouse.X, Mouse.Y)
end

function PluginMouse:GetRay(overridePos: Vector2?): Ray
	local mousePos = overridePos or PluginMouse:GetPosition()
	local viewportMouseRay = workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
	return viewportMouseRay
end

function PluginMouse:Raycast(raycastParams: RaycastParams, distance: number?, overridePos: Vector2?)
	local viewportMouseRay = self:GetRay(overridePos)
	local result = workspace:Raycast(
		viewportMouseRay.Origin,
		viewportMouseRay.Direction * (distance or RAY_DISTANCE),
		raycastParams
	)
	return result
end

function PluginMouse:Enable()
	plugin:Activate(true)
end

function PluginMouse:IsLeftDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

function PluginMouse:IsRightDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

function PluginMouse:IsMiddleDown(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
end

return PluginMouse
