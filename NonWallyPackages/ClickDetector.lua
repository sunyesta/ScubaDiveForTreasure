local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

-- Require the MouseTouch class
local MouseTouchClass = require(ReplicatedStorage.NonWallyPackages.MouseTouch)
local RayVisualizer = require(ReplicatedStorage.NonWallyPackages.RayVisualizer)

-- Instantiate MouseTouch with specific filters
-- We only want interactions that are NOT processed by GUI (for Touch)
-- Note: MouseTouch currently fires for all Mouse inputs regardless of these filters,
-- but for Touch it will correctly filter out GUI interactions.
local MouseTouch = MouseTouchClass.new({
	Gui = false,
	Thumbstick = true,
	Unprocessed = true,
})

local Player = Players.LocalPlayer
local RobloxMouse = Player:GetMouse()

local ClickDetector = {}
ClickDetector.__index = ClickDetector

-- private properties
ClickDetector._All = {}

-- public properties
ClickDetector.DefaultIcon = ""
ClickDetector.OverrideIcon = nil
ClickDetector.RaycastParams = RaycastParams.new()

ClickDetector._LastFoundClickDetector = Property.new()
ClickDetector._IsValid = true

-- privateMethods

-- RunService.Stepped:Connect(function(time, deltaTime)
--  print(#ClickDetector._All)
-- end)

function ClickDetector._DefaultRaycastFunction(raycastParams, distance)
	return function()
		return MouseTouch:Raycast(raycastParams, distance)
	end
end
-- todo fix icon not changing after adding a decorpart and then activating hair before update finishesb
function ClickDetector.new(priority)
	local self = setmetatable({}, ClickDetector)

	-- Private Properties
	self._Trove = Trove.new()
	self._Priority = priority or 0
	self._HoveringPart = self._Trove:Add(Property.new()) --todo add to trove
	self._ResultFilterFunction = function()
		return true
	end
	self.Name = nil

	-- Public Properties
	self.HoveringPart = self._Trove:Add(Property.ReadOnly(self._HoveringPart))
	self.LeftClick = self._Trove:Add(Signal.new())
	self.LeftDown = self._Trove:Add(Signal.new())
	self.LeftUp = self._Trove:Add(Signal.new())
	self.MouseIcon = "rbxassetid://103921226983289"

	ClickDetector._All, _ = TableUtil2.InsertSorted(ClickDetector._All, self, function(clickDetector1, clickDetector2)
		return clickDetector1._Priority > clickDetector2._Priority
	end)

	return self
end

function ClickDetector:Destroy()
	local _, i = TableUtil.Find(ClickDetector._All, function(clickDetector)
		return clickDetector == self
	end)
	ClickDetector._All[i] = nil

	if ClickDetector._LastFoundClickDetector:Get() == self then
		ClickDetector._LastFoundClickDetector:Set(nil)
	end

	self._Trove:Clean()
end

-- callback(result) -> bool
-- note: result will always be non nil
function ClickDetector:SetResultFilterFunction(callback)
	self._ResultFilterFunction = callback
end

function ClickDetector:GetBasePart(ignoreOverlappingDetectors, overridePos)
	if ignoreOverlappingDetectors then
		local result = MouseTouch:Raycast(ClickDetector.RaycastParams, 99999, overridePos)

		return if self._ResultFilterFunction(result) then result.Instance else nil
	else
		local clickDetector, result = ClickDetector._GetTopClickDetector(overridePos)
		return if clickDetector == self then result.Instance else nil
	end
end

-- Active

function ClickDetector._GetTopClickDetector(overridePos)
	local found = nil

	local result = MouseTouch:Raycast(ClickDetector.RaycastParams, 99999, overridePos)
	if result then
		for _, clickDetector in pairs(ClickDetector._All) do
			if (not found) and result and clickDetector._ResultFilterFunction(result) then
				found = clickDetector
				local part = if result then result.Instance else nil
				clickDetector._HoveringPart:Set(part)
			else
				clickDetector._HoveringPart:Set(nil)
			end
		end

		local foundIcon = if found then found.MouseIcon else nil
		RobloxMouse.Icon = ClickDetector.OverrideIcon or foundIcon or ClickDetector.DefaultIcon
		return found, result
	else
		return nil
	end
end

function ClickDetector.GetResultDistanceFromPlayer(result)
	return (result.Position - Player.Character:GetPivot().Position).Magnitude
end

function ClickDetector:ToggleCursorVisibility(toggle)
	UserInputService.MouseIconEnabled = toggle
end

RunService.RenderStepped:Connect(function(deltaTime)
	ClickDetector._GetTopClickDetector()
end)

-- MouseTouch signals return position (Vector2), not processed boolean.
-- Since we filtered Touch types in the constructor, we assume events here are valid for interaction.
MouseTouch.Moved:Connect(function(pos)
	-- ClickDetector._IsValid logic removed as processed check is not applicable
end)

local lastMouseDownPart = nil
MouseTouch.LeftDown:Connect(function(pos)
	-- Removed processed check; filtering is handled by MouseTouch instance for touch,
	-- and MouseTouch fires for all mouse inputs (limitation of MouseTouch module).

	-- Pass 'pos' to ensure we raycast from the event location, not stale internal state
	local clickDetector, result = ClickDetector._GetTopClickDetector(pos)
	if clickDetector then
		clickDetector.LeftDown:Fire(result.Instance, result)
		lastMouseDownPart = result.Instance
	end
end)

MouseTouch.LeftUp:Connect(function(pos)
	-- Pass 'pos' to ensure we raycast from the event location
	local clickDetector, result = ClickDetector._GetTopClickDetector(pos)
	if clickDetector then
		clickDetector.LeftUp:Fire(result.Instance)
		if lastMouseDownPart and result.Instance == lastMouseDownPart then
			clickDetector.LeftClick:Fire(result.Instance, result)
		end
		lastMouseDownPart = nil
	end
end)

return ClickDetector
