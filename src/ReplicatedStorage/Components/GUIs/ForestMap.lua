--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

--Packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Input = require(ReplicatedStorage.Packages.Input)
local Keyboard = Input.Keyboard.new()
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Property = require(ReplicatedStorage.NonWallyPackages.Property)

local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

--Instances
local Player = Players.LocalPlayer

-- UI Constants & Theming
local NODE_TYPES = {
	["Effect"] = { Icon = "✨", Color = Color3.fromRGB(192, 38, 211), TextColor = Color3.fromRGB(240, 171, 252) },
	["Battle"] = { Icon = "⚔️", Color = Color3.fromRGB(225, 29, 72), TextColor = Color3.fromRGB(253, 164, 175) },
	["Mystery"] = { Icon = "❓", Color = Color3.fromRGB(99, 102, 241), TextColor = Color3.fromRGB(165, 180, 252) },
	["?"] = { Icon = "❓", Color = Color3.fromRGB(99, 102, 241), TextColor = Color3.fromRGB(165, 180, 252) },
	["Shop"] = { Icon = "🛒", Color = Color3.fromRGB(245, 158, 11), TextColor = Color3.fromRGB(252, 211, 77) },
	["Elite"] = { Icon = "💀", Color = Color3.fromRGB(185, 28, 28), TextColor = Color3.fromRGB(252, 165, 165) },
	["Treasure"] = { Icon = "💎", Color = Color3.fromRGB(16, 185, 129), TextColor = Color3.fromRGB(110, 231, 183) },
	["Rest"] = { Icon = "☕", Color = Color3.fromRGB(249, 115, 22), TextColor = Color3.fromRGB(253, 186, 116) },
	["Boss"] = {
		Icon = "👑",
		Color = Color3.fromRGB(126, 34, 206),
		TextColor = Color3.fromRGB(216, 180, 254),
		Size = UDim2.fromOffset(64, 64),
	},
	["Ambush"] = { Icon = "🔥", Color = Color3.fromRGB(220, 38, 38), TextColor = Color3.fromRGB(252, 165, 165) },
	["Custom"] = { Icon = "🎨", Color = Color3.fromRGB(249, 115, 22), TextColor = Color3.fromRGB(253, 186, 116) },
	["Unknown"] = { Icon = "❌", Color = Color3.fromRGB(134, 134, 134), TextColor = Color3.fromRGB(253, 186, 116) },
}

local TWEEN_INFO_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_PULSE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Component Setup
local ForestMap = Component.new({
	Tag = "ForestMap",
	Ancestors = { Player },
})
ForestMap.IsOpen = Property.new(false)

function ForestMap:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()
end

function ForestMap:Start()
	self._Trove:Connect(Keyboard.KeyDown, function(keycode)
		if keycode == Enum.KeyCode.M then
			if ForestMap.IsOpen:Get() then
				ForestMap.Close()
			else
				ForestMap.Open()
			end
		end
	end)
end

function ForestMap:Stop()
	self._Trove:Clean()
end

-- ==========================================
-- Utility: Sound Generation
-- ==========================================
local function PlaySound(trove: any, soundType: string)
	local sound = Instance.new("Sound")

	if soundType == "hover" then
		sound.SoundId = "rbxassetid://876939830"
		sound.Volume = 0.5
		sound.PlaybackSpeed = 1.2
	elseif soundType == "success" then
		sound.SoundId = "rbxassetid://2865227271"
		sound.Volume = 0.6
	elseif soundType == "error" then
		sound.SoundId = "rbxassetid://255881176"
		sound.Volume = 0.4
	end

	sound.Parent = SoundService
	trove:Add(sound)
	sound:Play()

	task.delay(sound.TimeLength + 0.1, function()
		if sound.Parent then
			trove:Remove(sound)
			sound:Destroy()
		end
	end)
end

-- ==========================================
-- Main Open Logic
-- ==========================================
function ForestMap.Open()
	local self = ForestMap:GetAll()[1]
	if not self then
		return
	end

	local ScreenGui = self.Instance :: ScreenGui
	self._OpenTrove:Clean()

	ForestMap.IsOpen:Set(true)
	self._OpenTrove:Add(function()
		ForestMap.IsOpen:Set(false)
	end)

	-- 1. Fetch Data
	local graph = PlayerComm.ForestMap:Get()
	print(graph)

	if not graph then
		graph = {
			["StartNodeID"] = "6303b861-b9d0-495f-a43e-ceaf84f5bfc6",
			["CurrentNodeID"] = "6303b861-b9d0-495f-a43e-ceaf84f5bfc6",
			["Nodes"] = {
				["6303b861-b9d0-495f-a43e-ceaf84f5bfc6"] = {
					Depth = 1,
					IsVisited = true,
					Name = "Ambush",
					Connections = { ["a"] = "892154d6-d29f-44bd-8218-b1efc0f7a76d" },
				},
				["892154d6-d29f-44bd-8218-b1efc0f7a76d"] = {
					Depth = 2,
					IsVisited = false,
					Name = "?",
					Connections = { ["b"] = "a66b8e8a-0d80-4fe4-8567-368b53aa8849" },
				},
				["a66b8e8a-0d80-4fe4-8567-368b53aa8849"] = {
					Depth = 3,
					IsVisited = false,
					Name = "?",
					Connections = { ["c"] = "602c1c60-9527-4197-802e-bc2592d8d523" },
				},
				["602c1c60-9527-4197-802e-bc2592d8d523"] = {
					Depth = 4,
					IsVisited = false,
					Name = "Elite",
					Connections = { ["d"] = "3b0be2ac-2eb9-4df9-846f-5812701ac63a" },
				},
				["3b0be2ac-2eb9-4df9-846f-5812701ac63a"] = {
					Depth = 5,
					IsVisited = false,
					Name = "Boss",
					Connections = {},
				},
			},
		}
	end

	-- 2. Calculate Layout Positions
	local depthGroups = {}
	local maxDepth, minDepth = 0, 999
	for id, node in pairs(graph.Nodes) do
		depthGroups[node.Depth] = depthGroups[node.Depth] or {}
		table.insert(depthGroups[node.Depth], id)
		maxDepth = math.max(maxDepth, node.Depth)
		minDepth = math.min(minDepth, node.Depth)
	end

	local nodePositions = {}
	for depthStr, ids in pairs(depthGroups) do
		local depth = tonumber(depthStr)
		local normalized = (maxDepth == minDepth) and 0 or ((depth - minDepth) / (maxDepth - minDepth))
		local y = 0.85 - (normalized * 0.70)

		for index, id in ipairs(ids) do
			local x = index / (#ids + 1)
			if #ids > 1 then
				x += (depth % 2 == 0) and -0.04 or 0.04
			end
			nodePositions[id] = UDim2.new(x, 0, y, 0)
		end
	end

	-- 3. Construct Main UI
	local bgOverlay = Instance.new("Frame")
	bgOverlay.Name = "MapOverlay"
	bgOverlay.Size = UDim2.fromScale(1, 1)
	bgOverlay.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
	bgOverlay.BackgroundTransparency = 0.1
	bgOverlay.Parent = ScreenGui
	self._OpenTrove:Add(bgOverlay)

	local mapContainer = Instance.new("CanvasGroup")
	mapContainer.Name = "MapContainer"
	mapContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	mapContainer.Position = UDim2.fromScale(0.5, 0.5)
	mapContainer.Size = UDim2.fromOffset(450, 700)
	mapContainer.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	mapContainer.Parent = bgOverlay

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 24)
	uiCorner.Parent = mapContainer

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(30, 41, 59)
	uiStroke.Thickness = 2
	uiStroke.Parent = mapContainer

	-- 4. Tooltip (Thumbtip) Setup
	local tooltip = Instance.new("CanvasGroup")
	tooltip.Name = "Tooltip"
	tooltip.Size = UDim2.fromOffset(120, 50)
	tooltip.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.Visible = false
	tooltip.ZIndex = 50

	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, 12)
	tooltipCorner.Parent = tooltip

	local tooltipText = Instance.new("TextLabel")
	tooltipText.Size = UDim2.fromScale(1, 0.6)
	tooltipText.BackgroundTransparency = 1
	tooltipText.Font = Enum.Font.GothamBold
	tooltipText.TextSize = 14
	tooltipText.TextColor3 = Color3.new(1, 1, 1)
	tooltipText.Parent = tooltip

	local tooltipSubtext = Instance.new("TextLabel")
	tooltipSubtext.Size = UDim2.fromScale(1, 0.4)
	tooltipSubtext.Position = UDim2.fromScale(0, 0.6)
	tooltipSubtext.BackgroundTransparency = 1
	tooltipSubtext.Font = Enum.Font.Gotham
	tooltipSubtext.TextSize = 10
	tooltipSubtext.TextColor3 = Color3.fromRGB(148, 163, 184)
	tooltipSubtext.Parent = tooltip

	tooltip.Parent = mapContainer

	-- 5. Draw Lines (Connections)
	local linesFolder = Instance.new("Folder")
	linesFolder.Name = "Connections"
	linesFolder.Parent = mapContainer

	local dynamicLines = {}

	for sourceId, node in pairs(graph.Nodes) do
		for _, targetId in pairs(node.Connections) do
			local p1Scale = nodePositions[sourceId]
			local p2Scale = nodePositions[targetId]
			if not p1Scale or not p2Scale then
				continue
			end

			local targetNode = graph.Nodes[targetId]
			local isVisited = node.IsVisited and targetNode.IsVisited
			local isActivePath = sourceId == graph.CurrentNodeID

			local line = Instance.new("Frame")
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BorderSizePixel = 0
			line.ZIndex = 1

			if isVisited then
				line.BackgroundColor3 = Color3.fromRGB(6, 182, 212)
				line.Size = UDim2.new(0, 0, 0, 4)
			elseif isActivePath then
				line.BackgroundColor3 = Color3.fromRGB(192, 38, 211)
				line.Size = UDim2.new(0, 0, 0, 4)
			else
				line.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
				line.Size = UDim2.new(0, 0, 0, 2)
			end

			line.Parent = linesFolder
			table.insert(dynamicLines, { Frame = line, P1 = p1Scale, P2 = p2Scale })
		end
	end

	local function UpdateLines()
		local absSize = mapContainer.AbsoluteSize
		for _, data in ipairs(dynamicLines) do
			local p1Abs = Vector2.new(data.P1.X.Scale * absSize.X, data.P1.Y.Scale * absSize.Y)
			local p2Abs = Vector2.new(data.P2.X.Scale * absSize.X, data.P2.Y.Scale * absSize.Y)

			local distance = (p2Abs - p1Abs).Magnitude
			local center = (p1Abs + p2Abs) / 2
			local angle = math.deg(math.atan2(p2Abs.Y - p1Abs.Y, p2Abs.X - p1Abs.X))

			data.Frame.Size = UDim2.new(0, distance, 0, data.Frame.Size.Y.Offset)
			data.Frame.Position = UDim2.fromScale(center.X / absSize.X, center.Y / absSize.Y)
			data.Frame.Rotation = angle
		end
	end

	self._OpenTrove:Connect(mapContainer:GetPropertyChangedSignal("AbsoluteSize"), UpdateLines)
	UpdateLines()

	-- 6. Draw Nodes
	local nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "Nodes"
	nodesFolder.Parent = mapContainer

	for id, node in pairs(graph.Nodes) do
		local pos = nodePositions[id]
		local isCurrent = id == graph.CurrentNodeID

		local isAvailable = false
		local currentNodeData = graph.Nodes[graph.CurrentNodeID]
		for _, targetId in pairs(currentNodeData.Connections) do
			if targetId == id then
				isAvailable = true
				break
			end
		end

		local typeConfig = NODE_TYPES[node.Name] or NODE_TYPES["Unknown"]

		local nodeBtn = Instance.new("TextButton")
		nodeBtn.Name = node.Name
		nodeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		nodeBtn.Position = pos
		nodeBtn.Size = typeConfig.Size or UDim2.fromOffset(48, 48)
		nodeBtn.Text = typeConfig.Icon
		nodeBtn.TextSize = 24
		nodeBtn.ZIndex = 10

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(1, 0)
		btnCorner.Parent = nodeBtn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2
		btnStroke.Parent = nodeBtn

		if isCurrent then
			nodeBtn.BackgroundColor3 = typeConfig.Color
			btnStroke.Color = Color3.new(1, 1, 1)

			local pulseTween = TweenService:Create(btnStroke, TWEEN_INFO_PULSE, { Transparency = 1, Thickness = 6 })
			pulseTween:Play()
			self._OpenTrove:Add(pulseTween)
		elseif node.IsVisited then
			nodeBtn.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
			btnStroke.Color = Color3.fromRGB(71, 85, 105)
			nodeBtn.TextTransparency = 0.4
			nodeBtn.Size = UDim2.fromOffset(40, 40)
		elseif isAvailable then
			nodeBtn.BackgroundColor3 = typeConfig.Color
			btnStroke.Color = Color3.new(1, 1, 1)
			btnStroke.Transparency = 0.5
		else
			nodeBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
			btnStroke.Color = Color3.fromRGB(51, 65, 85)
			nodeBtn.TextTransparency = 0.5
			nodeBtn.Size = UDim2.fromOffset(40, 40)
		end

		-- Hover Events
		self._OpenTrove:Connect(nodeBtn.MouseEnter, function()
			PlaySound(self._OpenTrove, "hover")
			if isAvailable or isCurrent then
				TweenService:Create(
					nodeBtn,
					TWEEN_INFO_FAST,
					{ Size = (typeConfig.Size or UDim2.fromOffset(48, 48)) + UDim2.fromOffset(8, 8) }
				):Play()
			end

			tooltip.Position = pos - UDim2.fromOffset(0, (nodeBtn.Size.Y.Offset / 2) + 10)
			tooltipText.Text = string.upper(node.Name)
			tooltipText.TextColor3 = typeConfig.TextColor
			tooltipSubtext.Text = "DEPTH " .. tostring(node.Depth)

			tooltip.Visible = true
			tooltip.GroupTransparency = 1
			TweenService:Create(tooltip, TWEEN_INFO_FAST, { GroupTransparency = 0 }):Play()
		end)

		self._OpenTrove:Connect(nodeBtn.MouseLeave, function()
			if isAvailable or isCurrent then
				TweenService:Create(nodeBtn, TWEEN_INFO_FAST, { Size = typeConfig.Size or UDim2.fromOffset(48, 48) })
					:Play()
			end
			TweenService:Create(tooltip, TWEEN_INFO_FAST, { GroupTransparency = 1 }):Play()
		end)

		-- Click Event (Informational only, no travel)
		self._OpenTrove:Connect(nodeBtn.MouseButton1Click, function()
			PlaySound(self._OpenTrove, "hover") -- Gentle click feedback

			-- Print purely for debugging/informational purposes
			print(string.format("Clicked informational map node: [%s] at Depth %d", node.Name, node.Depth))

			-- NOTE: All travel networking, map closing, and error-shaking logic have been removed
			-- since this is just a read-only display map.
		end)

		nodeBtn.Parent = nodesFolder
	end

	-- Entrance animation
	mapContainer.Position = UDim2.fromScale(0.5, 0.55)
	mapContainer.GroupTransparency = 1
	TweenService:Create(mapContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
		GroupTransparency = 0,
	}):Play()
end

function ForestMap.Close()
	local self = ForestMap:GetAll()[1]
	if not self then
		return
	end
	self._OpenTrove:Clean()
end

return ForestMap
