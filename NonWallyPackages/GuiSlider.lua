local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local DefaultValue = require(ReplicatedStorage.NonWallyPackages.DefaultValue)
local Signal = require(ReplicatedStorage.Packages.Signal)
local UserInputUtils = require(ReplicatedStorage.NonWallyPackages.UserInputUtils)
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local MouseTouch = UserInputUtils.MouseTouch.new(true)

function lerp(start, goal, alpha)
	return start + (goal - start) * alpha
end

local GuiSlider = {}
GuiSlider.__index = GuiSlider

GuiSlider.Directions = {
	Vertical = "Vertical",
	Horizontal = "Horizontal",
}
local Directions = GuiSlider.Directions

function GuiSlider.new(params)
	-- set default values
	params = {
		Bar = params.Bar,
		Handle = params.Handle,
		Direction = params.Direction,

		IntOnly = DefaultValue(params.IntOnly, false),
		MinValue = DefaultValue(params.MinValue, 0),
		MaxValue = DefaultValue(params.MaxValue, 1),
		DefaultValue = DefaultValue(params.DefaultValue, DefaultValue(params.MinValue, 0)),
	}

	local self = setmetatable({}, GuiSlider)

	-- ensure safety
	assert(typeof(params.Bar) == "Instance" and params.Bar:IsA("ImageButton"), "bar must be an image button")
	assert(typeof(params.Handle) == "Instance" and params.Handle:IsA("ImageButton"), "cursor must be an image button")
	assert(params.Handle.Parent == params.Bar, "handle's parent must be the bar")

	self._Trove = Trove.new()

	-- init values
	self.Bar = params.Bar
	self.Handle = params.Handle

	self.Value = self._Trove:Add(Property.new(params.DefaultValue))
	self.Dragged = self._Trove:Add(Signal.new())
	self.MouseDown = self._Trove:Add(Signal.new())
	self.MouseUp = self._Trove:Add(Signal.new())

	self._MinValue = params.MinValue
	self._MaxValue = params.MaxValue
	self._Direction = params.Direction
	self._IntOnly = params.IntOnly

	-- configure bar
	self.Handle.AnchorPoint = Vector2.new(0.5, 0.5)

	local function updateHandlePosition()
		local position = math.clamp((self.Value:Get() - self._MinValue) / (self._MaxValue - self._MinValue), 0, 1)

		if self._Direction == GuiSlider.Directions.Horizontal then
			self.Handle.Position = UDim2.new(position, 0, 0, self.Bar.AbsoluteSize.Y / 2)
		elseif self._Direction == GuiSlider.Directions.Vertical then
			self.Handle.Position = UDim2.new(0, self.Bar.AbsoluteSize.X / 2, position, 0)
		else
			error("unknown guislider direction " .. self._Direction)
		end
	end

	self.Value:Observe(updateHandlePosition)

	local mouseDownTrove = self._Trove:Extend()
	local function mouseDownBehavior()
		local function valueToMouse()
			local relativePosition = (Vector2.new(Mouse.X, Mouse.Y) - self.Bar.AbsolutePosition) / self.Bar.AbsoluteSize

			local alpha
			if self._Direction == Directions.Horizontal then
				alpha = relativePosition.X
			else
				alpha = relativePosition.Y
			end

			-- adjust value
			local newValue = lerp(self._MinValue, self._MaxValue, math.clamp(alpha, 0, 1))

			if self._IntOnly then
				newValue = math.round(newValue)
			end

			self.Value:Set(newValue)
			self.Dragged:Fire(newValue)
		end

		self.MouseDown:Fire()
		mouseDownTrove:Add(function()
			self.MouseUp:Fire()
		end)

		valueToMouse()
		mouseDownTrove:Add(MouseTouch.Moved:Connect(valueToMouse))

		mouseDownTrove:Add(MouseTouch.LeftUp:Connect(function()
			mouseDownTrove:Clean()
		end))
	end

	self._Trove:Add(self.Bar.MouseButton1Down:Connect(mouseDownBehavior))
	self._Trove:Add(self.Handle.MouseButton1Down:Connect(mouseDownBehavior))

	return self
end

function GuiSlider:Destroy()
	self._Trove:Clean()
end

return GuiSlider
