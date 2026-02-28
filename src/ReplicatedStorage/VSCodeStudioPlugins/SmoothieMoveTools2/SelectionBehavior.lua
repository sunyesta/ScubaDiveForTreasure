--!strict

local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local Props = require(script.Parent.Props)
local Enums = require(script.Parent.Enums)

local SelectionBehavior = {}
SelectionBehavior._Dot = nil

-- Tracks if the user is currently rotating/moving parts to freeze recalculation
SelectionBehavior.IsTransforming = false

--------------------------------------------------------------------------------
-- MATH HELPERS
--------------------------------------------------------------------------------

-- Calculates a near-optimal Minimum Enclosing Sphere using Ritter's Algorithm.
-- This algorithm is O(n) and avoids the recursion limits of Welzl's Algorithm.
local function GetRitthersBoundingSphereCenter(points: { Vector3 }): Vector3
	local count = #points

	-- Handle base cases quickly
	if count == 0 then
		return Vector3.zero
	end
	if count == 1 then
		return points[1]
	end
	if count == 2 then
		return (points[1] + points[2]) / 2
	end

	-- Step 1: Find an arbitrary starting extreme point (y) from the first point (x)
	local x = points[1]
	local y = x
	local maxDistSq = 0

	for i = 2, count do
		-- Using squared magnitude is faster for distance comparisons
		local distSq = (points[i] - x).Magnitude
		if distSq > maxDistSq then
			maxDistSq = distSq
			y = points[i]
		end
	end

	-- Step 2: Find the opposite extreme point (z) from (y)
	local z = y
	maxDistSq = 0

	for i = 1, count do
		local distSq = (points[i] - y).Magnitude
		if distSq > maxDistSq then
			maxDistSq = distSq
			z = points[i]
		end
	end

	-- Step 3: Initialize the sphere using the two extreme points
	local center = (y + z) / 2
	local radius = (y - z).Magnitude / 2

	-- Step 4: Expand the sphere iteratively to include any points that fall outside
	for i = 1, count do
		local p = points[i]
		local dist = (p - center).Magnitude

		-- If the point is outside our current bounding sphere...
		if dist > radius then
			-- Calculate the new radius required to encompass the point
			local newRadius = (radius + dist) / 2
			-- Shift the center towards the outside point just enough to fit it
			local direction = (p - center).Unit
			center = center + direction * (newRadius - radius)
			radius = newRadius
		end
	end

	return center
end

--------------------------------------------------------------------------------
-- ORIGIN CALCULATION
--------------------------------------------------------------------------------

-- Calculates the global TransformOrigin based on properties and selection
function SelectionBehavior.CalculateTransformOrigin(): CFrame
	local originMode = Props.Origin:Get()
	local activePart = Props.ActivePart:Get()
	local selectedParts = Props.SelectedParts:Get()

	local newOrigin: CFrame

	if #selectedParts == 0 then
		return CFrame.new()
	end

	if originMode == Enums.Origin.Pivot and activePart then
		-- Use the built-in Pivot API
		newOrigin = activePart:GetPivot()
	else
		-- Center Mode: Calculate the center using Ritter's Minimum Enclosing Sphere algorithm
		local positions: { Vector3 } = {}

		for _, part in ipairs(selectedParts) do
			if part:IsA("BasePart") then
				table.insert(positions, part.Position)
			end
		end

		-- Get our center point using the math helper
		local center: Vector3 = GetRitthersBoundingSphereCenter(positions)

		-- Apply the rotation of the active part (or identity if none exists)
		local rotation: CFrame = activePart and activePart:GetPivot().Rotation or CFrame.identity
		newOrigin = CFrame.new(center) * rotation
	end

	-- Immediately update visualizer dot to prevent 1-frame lags if possible
	if SelectionBehavior._Dot then
		local screenPos, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(newOrigin.Position)
		SelectionBehavior._Dot.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
	end

	return newOrigin
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

-- This initialization function sets up the visualizer and selection connections
function SelectionBehavior.Init(plugin: Plugin, pluginTrove: any)
	print("plugin started")

	-- Create the Selection Visualizer GUI
	local selectionGui = Instance.new("ScreenGui")
	selectionGui.Name = "SelectionVisualizerGui"
	-- Parenting to CoreGui allows the UI to render directly over the 3D viewport in Studio
	selectionGui.Parent = CoreGui
	pluginTrove:Add(selectionGui)

	local dot = Instance.new("Frame")
	dot.Name = "ActivePartDot"
	dot.Size = UDim2.fromOffset(6, 6)
	dot.AnchorPoint = Vector2.new(0.5, 0.5) -- Center the UI element exactly on its position
	dot.BackgroundColor3 = Color3.new(0, 1, 0) -- Green
	dot.BorderSizePixel = 0
	dot.Visible = false
	dot.Parent = selectionGui
	SelectionBehavior._Dot = dot

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0) -- Makes the square frame a perfect circle
	corner.Parent = dot

	-- Updates the Props state whenever the user selects or deselects objects in Studio
	local function UpdateSelection()
		-- :Get() returns an array of all currently selected instances in Studio
		local selected = Selection:Get()
		Props.SelectedObjects:Set(selected)

		local addedParts = {}

		local selectedParts = TableUtil.Filter(selected, function(inst: Instance)
			if inst:IsA("BasePart") then
				return true
			elseif inst:IsA("Model") then
				-- If a Model is selected, extract its internal parts
				for _, inst2 in inst:GetDescendants() do
					if inst2 ~= inst.PrimaryPart and inst2:IsA("BasePart") then
						table.insert(addedParts, inst2)
					end
				end

				-- Ensure the PrimaryPart is included if it exists
				if inst.PrimaryPart then
					table.insert(addedParts, inst.PrimaryPart)
				end
			end

			return false
		end)

		-- Merge the manually extracted model parts with the directly selected parts
		selectedParts = TableUtil.Extend(selectedParts, addedParts)
		Props.SelectedParts:Set(selectedParts)

		-- Update ActivePart: Usually the most recently selected valid part
		if #selectedParts > 0 then
			Props.ActivePart:Set(selectedParts[#selectedParts])
		else
			Props.ActivePart:Set(nil)
		end
	end

	-- Run immediately to catch any selection made before the plugin started
	UpdateSelection()

	-- Listen for any changes to the Studio selection
	pluginTrove:Add(Selection.SelectionChanged:Connect(function()
		UpdateSelection()
	end))

	-- The identifier for our RenderStep binding
	local RENDER_STEP_NAME = "SelectionVisualizerUpdate"

	-- Ensure we clean up the RenderStep connection when the plugin is destroyed
	pluginTrove:Add(function()
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	end)

	-- Observe the ActivePart property to toggle the visualizer and update its position
	pluginTrove:Add(Props.ActivePart:Observe(function(activePart: BasePart?)
		-- FIX: Always unbind the previous function before binding a new one!
		-- This prevents Roblox from stacking different functions onto the same render step name.
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)

		if activePart then
			-- Start tracking the part with a brand new closure
			RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
				local transformCFrame

				-- Freeze logic: Only calculate fresh bounds if we are NOT transforming
				if SelectionBehavior.IsTransforming and Props.TransformOrigin:Get() then
					transformCFrame = Props.TransformOrigin:Get()
				else
					transformCFrame = SelectionBehavior.CalculateTransformOrigin()
					Props.TransformOrigin:Set(transformCFrame)
				end

				-- WorldToScreenPoint translates a 3D world position into 2D screen coordinates
				-- 'onScreen' is a boolean indicating if the point is actually in front of the camera
				local screenPos, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(transformCFrame.Position)

				if onScreen then
					-- Update the UI to hover directly over the calculated origin
					dot.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
					dot.Visible = true
				else
					-- Hide the dot if the camera is facing away from the origin
					dot.Visible = false
				end
			end)
		else
			-- No active part; hide the dot to save resources
			dot.Visible = false
			-- Reset the TransformOrigin when nothing is selected
			Props.TransformOrigin:Set(CFrame.new())
		end
	end))

	pluginTrove:Add(Props.SelectedObjects:Observe(function(selectedObjects)
		-- Optional: Keep or remove debug print
		-- print(selectedObjects)
	end))
end

return SelectionBehavior
