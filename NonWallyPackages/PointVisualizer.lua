local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- build visPart
local Folder = Instance.new("Folder")
Folder.Name = "VisParts"
Folder.Parent = Workspace

local visPart = Instance.new("Part")
visPart.Size = Vector3.new(1, 1, 1)
visPart.CanCollide = false
visPart.CanTouch = false
visPart.CanQuery = false
visPart.Transparency = 0
visPart.Color = Color3.new(1, 0, 0)
visPart.Anchored = true

local textures = {
	Front = "rbxassetid://116059630986303",
	Back = "rbxassetid://90503452231306",
	Left = "rbxassetid://100367642147938",
	Right = "rbxassetid://92352056917966",
	Top = "rbxassetid://90171533500230",
	Bottom = "rbxassetid://84963270235039",
}

for _, normalID in pairs(Enum.NormalId:GetEnumItems()) do
	local decal = Instance.new("Decal")
	decal.Face = normalID
	decal.Parent = visPart

	if normalID == Enum.NormalId.Front then
		decal.Texture = textures.Front
	elseif normalID == Enum.NormalId.Back then
		decal.Texture = textures.Back
	elseif normalID == Enum.NormalId.Left then
		decal.Texture = textures.Left
	elseif normalID == Enum.NormalId.Right then
		decal.Texture = textures.Right
	elseif normalID == Enum.NormalId.Top then
		decal.Texture = textures.Top
	elseif normalID == Enum.NormalId.Bottom then
		decal.Texture = textures.Bottom
	end
end

-- 2D Visualizer Setup
local VisGui
if Players.LocalPlayer then
	VisGui = Instance.new("ScreenGui")
	VisGui.Name = "VisPoints"
	VisGui.IgnoreGuiInset = true
	VisGui.DisplayOrder = 100 -- Ensure it's on top
	VisGui.ResetOnSpawn = false
	VisGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local PointVisualizer = {}

function PointVisualizer.new(point, time)
	-- Handle 2D Point (Vector2)
	if typeof(point) == "Vector2" then
		if not VisGui then
			return nil -- Cannot create GUI on server or if setup failed
		end

		local frame = Instance.new("Frame")
		frame.Name = "VisPoint"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.fromOffset(10, 10)
		frame.Position = UDim2.fromOffset(point.X, point.Y)
		frame.BackgroundColor3 = Color3.new(1, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = VisGui

		-- Optional: Make it circular
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame

		if time then
			task.delay(time, function()
				if frame and frame.Parent then
					frame:Destroy()
				end
			end)
		end

		return frame

	-- Handle 3D Point (Vector3 or CFrame)
	else
		local cframe = point
		if typeof(cframe) == "Vector3" then
			cframe = CFrame.new(cframe)
		end

		local newPart = visPart:Clone()
		newPart.Parent = Folder
		newPart:PivotTo(cframe)

		if time then
			task.delay(time, function()
				if newPart.Parent then
					newPart:Destroy()
				end
			end)
		end

		return newPart
	end
end

return PointVisualizer
