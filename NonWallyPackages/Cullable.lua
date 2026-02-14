--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Adjust these paths to match your project structure
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

assert(RunService:IsClient(), "Cullable is only runnable on the client")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local DEFAULT_PADDING = 30 -- Pixels outside the screen to keep the object "alive"

--[=[
    @class Cullable
    @client

    A wrapper that mimics the API of 'Streamable', but decides existence based on
    Camera visibility (Frustum Culling) rather than network streaming.

    Useful for disabling expensive effects (beams, particles, complex animations)
    when they are not on screen.
]=]
local Cullable = {}
Cullable.__index = Cullable

type Cullable = {
	_trove: any,
	_shown: any,
	_shownTrove: any,
	_target: any,
	_check: (self: Cullable) -> boolean,
	_isVisible: boolean,
	Instance: any?,
	Observe: (self: Cullable, handler: (target: any, trove: any) -> ()) -> any,
	Destroy: (self: Cullable) -> (),
}

--// Helper Functions //--

local function IsOnScreen(position: Vector3, padding: number?): boolean
	local pad = padding or DEFAULT_PADDING
	local viewportPoint, inFrustum = Camera:WorldToViewportPoint(position)

	-- If strictly in frustum, return true immediately
	if inFrustum then
		return true
	end

	-- If not strictly in frustum, check if it's just outside the edge (padding)
	-- We also ensure z > 0 so we don't render things behind the camera
	if viewportPoint.Z > 0 then
		local viewportSize = Camera.ViewportSize
		return (viewportPoint.X >= -pad and viewportPoint.X <= viewportSize.X + pad)
			and (viewportPoint.Y >= -pad and viewportPoint.Y <= viewportSize.Y + pad)
	end

	return false
end

--// Constructor //--

function Cullable.new(target: any, checkFn: (self: Cullable) -> boolean)
	local self = setmetatable({}, Cullable)

	self._trove = Trove.new()
	self._shown = self._trove:Construct(Signal)
	self._shownTrove = Trove.new() -- Active trove when visible
	self._trove:Add(self._shownTrove)

	self._target = target
	self._check = checkFn
	self._isVisible = false

	-- Public exposed property for "If it exists right now"
	self.Instance = nil

	-- Start the render loop
	-- We use RenderStepped to ensure checks happen before frame drawing
	self._trove:Connect(RunService.RenderStepped, function()
		self:_Update()
	end)

	-- Run initial check immediately
	self:_Update()

	return self
end

--// Static Constructors //--

--[=[
    Creates a Cullable that tracks a BasePart's Position.
    @param basePart BasePart -- The part to track
]=]
function Cullable.NewForBasePart(basePart: BasePart)
	return Cullable.new(basePart, function(self)
		if not basePart or not basePart:IsDescendantOf(workspace) then
			return false
		end
		return IsOnScreen(basePart.Position)
	end)
end

--[=[
    Creates a Cullable that tracks a static point in world space with a radius.
    @param origin Vector3 -- Center position
    @param radius number -- (Optional) Extra padding to add to the screen buffer
]=]
function Cullable.NewForSphere(origin: Vector3, radius: number)
	local padding = DEFAULT_PADDING + (radius or 0)
	return Cullable.new(origin, function(self)
		return IsOnScreen(origin, padding)
	end)
end

--[=[
    Creates a Cullable that tracks a bounding box defined by two corner vectors.
    Calculates the center and treats it as a sphere with a radius large enough to cover the box.
    @param min Vector3 -- "TopLeft" or Min bounds
    @param max Vector3 -- "TopRight" or Max bounds
]=]
function Cullable.NewForBox(min: Vector3, max: Vector3)
	local center = (min + max) / 2
	local size = max - min
	local radius = size.Magnitude / 2
	local padding = DEFAULT_PADDING + radius

	return Cullable.new(center, function(self)
		return IsOnScreen(center, padding)
	end)
end

--// Methods //--

function Cullable:_Update()
	local currentlyVisible = self:_check()

	if currentlyVisible ~= self._isVisible then
		self._isVisible = currentlyVisible

		if currentlyVisible then
			-- BECAME VISIBLE
			self.Instance = self._target

			-- Recreate the trove for this session of visibility
			-- Note: We clean the old one first just to be safe, though strict logic handles it
			self._shownTrove:Clean()

			-- Fire signal (Target, Trove)
			self._shown:Fire(self._target, self._shownTrove)
		else
			-- BECAME INVISIBLE
			self.Instance = nil
			self._shownTrove:Clean()
		end
	end
end

--[=[
    Observes the culling state.
    The handler is called when the object comes into view.
    The trove passed to the handler is cleaned up when the object goes out of view.
    
    @param handler (target: any, trove: Trove) -> nil
    @return Connection
]=]
function Cullable:Observe(handler)
	if self._isVisible then
		task.spawn(handler, self._target, self._shownTrove)
	end
	return self._shown:Connect(handler)
end

--[=[
    Stops the culling check and cleans up all observers.
]=]
function Cullable:Destroy()
	self._trove:Destroy()
end

return Cullable
