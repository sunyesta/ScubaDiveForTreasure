local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local MultiTouch = require(ReplicatedStorage.NonWallyPackages.MultiTouch)
local PointVisualizer = require(ReplicatedStorage.NonWallyPackages.PointVisualizer)
local RayVisualizer = require(ReplicatedStorage.NonWallyPackages.RayVisualizer)

local RAY_DISTANCE = 100000

-- Default filter allows everything if not specified
local DEFAULT_TOUCH_TYPES = {
	Gui = true,
	Thumbstick = true,
	Unprocessed = true,
}

local MouseTouch = {}
MouseTouch.__index = MouseTouch

-- Expose TouchType from MultiTouch for convenience
MouseTouch.TouchType = MultiTouch.TouchType

function MouseTouch.new(allowedTouchTypes)
	local self = setmetatable({}, MouseTouch)

	-- Configuration
	self._allowedTouchTypes = allowedTouchTypes or DEFAULT_TOUCH_TYPES

	-- State
	self._Trove = Trove.new()
	self._lastMouseLocation = UserInputService:GetMouseLocation()
	self._isTouchDown = false
	self._isMouseDown = false

	-- Track the specific touch ID we are locked onto
	self._activeTouchId = nil

	-- Signals
	self.Moved = self._Trove:Add(Signal.new())
	self.LeftDown = self._Trove:Add(Signal.new())
	self.LeftUp = self._Trove:Add(Signal.new())

	-- Setup Input Listeners
	self:_setupMouseInputs()
	self:_setupTouchInputs()

	return self
end

function MouseTouch:_setupMouseInputs()
	-- Mouse Movement
	self._Trove:Add(UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- If Gui is false, we ignore inputs that were processed by the engine (UI/Game core)
			if not self._allowedTouchTypes.Gui and processed then
				return
			end

			-- On mobile, if we are tracking a touch, ignore simulated mouse movement
			if self._isTouchDown then
				return
			end

			local pos = UserInputService:GetMouseLocation()

			self._lastMouseLocation = pos
			self.Moved:Fire(pos)
		end
	end))

	-- Mouse Down
	self._Trove:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- If Gui is false, we ignore inputs that were processed by the engine (UI/Game core)
			if not self._allowedTouchTypes.Gui and processed then
				return
			end

			if self._isTouchDown then
				return
			end

			local pos = UserInputService:GetMouseLocation()

			self._isMouseDown = true
			self._lastMouseLocation = pos
			self.LeftDown:Fire(pos)
		end
	end))

	-- Mouse Up
	self._Trove:Add(UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- If Gui is false, we ignore inputs that were processed by the engine (UI/Game core)
			if not self._allowedTouchTypes.Gui and processed then
				return
			end

			if self._isTouchDown then
				return
			end

			local pos = UserInputService:GetMouseLocation()

			self._isMouseDown = false
			self._lastMouseLocation = pos
			self.LeftUp:Fire(pos)
		end
	end))
end

function MouseTouch:_setupTouchInputs()
	self._Trove:Add(MultiTouch.TouchPositions:Observe(function(rawTouchPositions)
		self:_updateFromTouches(rawTouchPositions)
	end))
end

function MouseTouch:_updateFromTouches(rawTouchPositions)
	-- Filter touches returns a map {[ID] = Position}
	-- We use this to decide if we should START tracking a NEW touch.
	local filteredPositions = MultiTouch:FilterTouchPositions(rawTouchPositions, self._allowedTouchTypes)

	if self._activeTouchId then
		-- We are already tracking a touch. Check if it still exists in the RAW list.
		-- Once we lock onto a finger, we want to keep tracking it even if it enters
		-- a filtered state (e.g. moves over a GUI button), preventing "swapping" to other fingers.

		local touchData = rawTouchPositions[self._activeTouchId]
		local pos = nil

		if touchData then
			-- Handle if touchData is the raw table or just the position
			if typeof(touchData) == "table" and touchData.Position then
				pos = touchData.Position
			elseif typeof(touchData) == "Vector2" or typeof(touchData) == "Vector3" then
				pos = touchData
			end

			if pos then
				-- Ensure Vector2 (Touch positions are often Vector3)
				if typeof(pos) == "Vector3" then
					pos = Vector2.new(pos.X, pos.Y)
				end

				-- Touch moved: Update location and fire
				self._lastMouseLocation = pos

				self.Moved:Fire(pos)
				return -- Exit early, we maintain the lock on this ID
			end
		end

		-- Touch ended or invalid data: The locked ID is gone from the screen entirely
		self._activeTouchId = nil
		self._isTouchDown = false
		self.LeftUp:Fire(self._lastMouseLocation)

		-- Fall through to check if another finger is already down...
	end

	-- If we are here, we are not locked onto a touch.
	-- Check if there are any valid touches to pick up.
	local id, pos = next(filteredPositions)

	if id then
		-- Ensure we have the position vector, not a table
		if typeof(pos) == "table" and pos.Position then
			pos = pos.Position
		end

		-- Ensure Vector2
		if typeof(pos) == "Vector3" then
			pos = Vector2.new(pos.X, pos.Y)
		end

		self._activeTouchId = id
		self._isTouchDown = true
		self._lastMouseLocation = pos
		self.LeftDown:Fire(pos)
	end
end

function MouseTouch:IsLeftDown()
	return self._isMouseDown or self._isTouchDown
end

function MouseTouch:GetPosition()
	if UserInputService.TouchEnabled and not self._isTouchDown then
		return UserInputService:GetMouseLocation()
	end
	-- Fallback to current mouse location if _lastMouseLocation is somehow nil
	return self._lastMouseLocation or UserInputService:GetMouseLocation()
end

function MouseTouch:GetRay(overridePos: Vector2?): Ray
	local mousePos = overridePos or self:GetPosition()

	-- Safety check: ensure mousePos is valid and extract coordinates
	local x, y
	if typeof(mousePos) == "Vector2" or typeof(mousePos) == "Vector3" then
		x, y = mousePos.X, mousePos.Y
	elseif typeof(mousePos) == "Instance" and mousePos:IsA("InputObject") then
		x, y = mousePos.Position.X, mousePos.Position.Y
	else
		-- Absolute fallback
		local current = UserInputService:GetMouseLocation()
		x, y = current.X, current.Y
	end

	local viewportMouseRay = workspace.CurrentCamera:ViewportPointToRay(x, y)
	return viewportMouseRay
end

function MouseTouch:Raycast(raycastParams: RaycastParams, distance: number?, overridePos: Vector2?)
	local viewportMouseRay = self:GetRay(overridePos)
	local result = workspace:Raycast(
		viewportMouseRay.Origin,
		viewportMouseRay.Direction * (distance or RAY_DISTANCE),
		raycastParams
	)

	return result
end

function MouseTouch:Destroy()
	self._Trove:Clean()
end

return MouseTouch
