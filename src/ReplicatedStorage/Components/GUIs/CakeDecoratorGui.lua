--!strict
--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--Packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local MainGuiController = require(ReplicatedStorage.Common.Controllers.MainGuiController)
local CakeDecoratorTabs = require(ReplicatedStorage.Common.GameInfo.CakeDecoratorTabs)
local View3DFrame = require(ReplicatedStorage.Common.Modules.View3DFrame)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)
local GuiListManager = require(ReplicatedStorage.NonWallyPackages.GuiListManager)

--Instances
local Player = Players.LocalPlayer

local CakeDecoratorGui = Component.new({
	Tag = "CakeDecoratorGui",
	Ancestors = { Player },
})

CakeDecoratorGui.IsOpen = Property.new(false)
CakeDecoratorGui.Singleton = true

-- Constants for our Active Tab Visuals
local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACTIVE_BG_COLOR = Color3.new(0.996078, 0.968627, 0.909804)
local ACTIVE_TEXT_COLOR = Color3.fromRGB(219, 39, 119)
local ACTIVE_STROKE_COLOR = Color3.fromRGB(225, 225, 225)

function CakeDecoratorGui:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()
	self.Gui = self.Instance

	-- UI References
	self.MainPanel = self.Gui:WaitForChild("MainPanel")
	self.TabsContainer = self.MainPanel:WaitForChild("TabsContainer")

	-- Add View References
	self.Views = self.MainPanel:WaitForChild("Views")
	self.AssetView = self.Views:WaitForChild("AssetView")
	self.ColorView = self.Views:WaitForChild("ColorView")
	self.PaintView = self.Views:WaitForChild("PaintView")
	self.SprinklesView = self.Views:WaitForChild("SprinklesView")

	-- Setup AssetView Elements
	self.CardsContainer = self.AssetView:WaitForChild("CardsContainer")
	self.SectionTitle = self.AssetView:WaitForChild("SectionTitle")

	-- Cache the Card Template and remove the original from the UI
	local originalCard = self.CardsContainer:WaitForChild("Card")
	self.CardTemplate = originalCard:Clone()
	self.CardTemplate.Visible = true
	originalCard:Destroy()

	-- 🚀 Initialize GuiListManager State
	self.CardViews = {} -- Cache for our View3DFrame objects so we don't recreate them

	self.AssetListManager = self._Trove:Construct(
		GuiListManager,
		self.CardsContainer,
		-- 1. CreateGui Callback: Fired ONLY when a new card needs to be instantiated from the pool
		function(): GuiObject
			local newCard = self.CardTemplate:Clone()
			local frame = newCard:WaitForChild("Frame")

			-- Setup the View3DFrame once and cache it associated with this GUI
			local view3DFrame = View3DFrame.new(frame)
			self.CardViews[newCard] = view3DFrame

			return newCard
		end,

		-- 2. UpdateGui Callback: Fired when an active card needs to show new data (or recycled)
		function(card: GuiObject, assetName: string)
			card.Name = assetName
			local view3DFrame = self.CardViews[card]

			if not view3DFrame then
				return
			end

			-- Clean up the previously displayed 3D model (if this card was recycled)
			for _, child in ipairs(view3DFrame.Instance:GetChildren()) do
				if child:IsA("Model") or child:IsA("BasePart") then
					child:Destroy()
				end
			end

			-- Setup the new asset
			local asset = GetAssetByName(assetName)
			if asset then
				local clone = asset:Clone()
				clone.Parent = view3DFrame.Instance
				view3DFrame:FocusOnBoundingBox()
			else
				warn("Asset not found:", assetName)
			end
		end
	)

	-- Store defaults so we can revert tabs when they become inactive
	self.TabDefaults = {}
	self.ActiveTabName = ""

	-- Setup the Tabs
	for _, tab in ipairs(self.TabsContainer:GetChildren()) do
		if tab:IsA("TextButton") then
			local stroke = tab:FindFirstChild("UIStroke")

			self.TabDefaults[tab.Name] = {
				BackgroundColor3 = tab.BackgroundColor3,
				Size = tab.Size,
				Position = tab.Position,
				ZIndex = tab.ZIndex,
				StrokeColor = stroke and stroke.Color or Color3.new(0, 0, 0),
			}

			-- Connect the click event
			self._Trove:Connect(tab.Activated, function()
				self:SetActiveTab(tab.Name)
			end)

			-- Hover Enter Animation
			self._Trove:Connect(tab.MouseEnter, function()
				if self.ActiveTabName == tab.Name then
					return
				end

				local default = self.TabDefaults[tab.Name]
				local hoverSize = UDim2.new(
					default.Size.X.Scale + 0.05,
					default.Size.X.Offset,
					default.Size.Y.Scale,
					default.Size.Y.Offset
				)
				local hoverPosition = UDim2.new(
					default.Position.X.Scale - 0.05,
					default.Position.X.Offset,
					default.Position.Y.Scale,
					default.Position.Y.Offset
				)
				local hoverBgColor = default.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.2)

				TweenService:Create(tab, TWEEN_INFO, {
					Size = hoverSize,
					Position = hoverPosition,
					BackgroundColor3 = hoverBgColor,
				}):Play()
			end)

			-- Hover Leave Animation
			self._Trove:Connect(tab.MouseLeave, function()
				if self.ActiveTabName == tab.Name then
					return
				end

				local default = self.TabDefaults[tab.Name]
				TweenService:Create(tab, TWEEN_INFO, {
					Size = default.Size,
					Position = default.Position,
					BackgroundColor3 = default.BackgroundColor3,
				}):Play()
			end)
		end
	end

	self:SetActiveTab("Color")
end

-- Sets up the AssetView with the correct title and dynamically generated cards
function CakeDecoratorGui:SetupAssetTab(tabData: table)
	self.SectionTitle.Text = tabData.Title or "Assets"

	-- 🚀 GuiListManager Handles the complex UI recycling and sorting for us!
	local assets = tabData.Assets or {}
	self.AssetListManager:Update(assets)
end

-- Core logic to handle tab animations and states
function CakeDecoratorGui:SetActiveTab(activeTabName: string)
	self.ActiveTabName = activeTabName

	-- 1. Handle Visual Tweening for Tab Buttons
	for _, tab in ipairs(self.TabsContainer:GetChildren()) do
		if not tab:IsA("TextButton") then
			continue
		end

		local isSelected = (tab.Name == activeTabName)
		local default = self.TabDefaults[tab.Name]

		local tabNameLabel = tab:FindFirstChild("TabName")
		local stroke = tab:FindFirstChild("UIStroke")

		local targetBgColor = isSelected and ACTIVE_BG_COLOR or default.BackgroundColor3
		local targetSize = isSelected and UDim2.new(1.15, 0, default.Size.Y.Scale, 0) or default.Size
		local targetPosition = isSelected
				and UDim2.new(
					default.Position.X.Scale - 0.15,
					default.Position.X.Offset,
					default.Position.Y.Scale,
					default.Position.Y.Offset
				)
			or default.Position

		local targetZIndex = isSelected and 10 or default.ZIndex
		local targetTextColor = isSelected and ACTIVE_TEXT_COLOR or Color3.new(1, 1, 1)
		local targetStrokeColor = isSelected and ACTIVE_STROKE_COLOR or default.StrokeColor

		tab.ZIndex = targetZIndex
		if tabNameLabel then
			tabNameLabel.ZIndex = targetZIndex + 1
		end

		TweenService:Create(tab, TWEEN_INFO, {
			BackgroundColor3 = targetBgColor,
			Size = targetSize,
			Position = targetPosition,
		}):Play()

		if tabNameLabel then
			TweenService:Create(tabNameLabel, TWEEN_INFO, { TextColor3 = targetTextColor }):Play()
		end

		if stroke then
			TweenService:Create(stroke, TWEEN_INFO, {
				Color = targetStrokeColor,
				Transparency = 0,
			}):Play()
		end
	end

	local function showTab(tab)
		self.ColorView.Visible = false
		self.AssetView.Visible = false
		self.PaintView.Visible = false
		self.SprinklesView.Visible = false
		tab.Visible = true
	end

	-- 2. Handle View Switching based on Tab Type
	local tabData = CakeDecoratorTabs[activeTabName]

	if tabData then
		if tabData.Type == "Color" then
			showTab(self.ColorView)
		elseif tabData.Type == "Asset" then
			self:SetupAssetTab(tabData)
			showTab(self.AssetView)
		elseif tabData.Type == "Paint" then
			showTab(self.PaintView)
		elseif tabData.Type == "Sprinkles" then
			showTab(self.SprinklesView)
		end
	else
		warn("No tab configuration found for:", activeTabName)
	end
end

function CakeDecoratorGui:Start() end

function CakeDecoratorGui:Stop()
	self._Trove:Clean()
end

function CakeDecoratorGui.Open()
	if CakeDecoratorGui.IsOpen:Get() then
		return
	end

	local self = CakeDecoratorGui:GetAll()[1]
	if not self then
		return
	end

	self.Gui.Enabled = true
	CakeDecoratorGui.IsOpen:Set(true)

	self._OpenTrove:Add(function()
		CakeDecoratorGui.IsOpen:Set(false)
	end)
end

function CakeDecoratorGui.Close()
	local self = CakeDecoratorGui:GetAll()[1]
	if not self then
		return
	end

	self.Gui.Enabled = false
	self._OpenTrove:Clean()
end

MainGuiController.Register("CakeDecoratorGui", function()
	CakeDecoratorGui.Open()
	return CakeDecoratorGui.Close
end)

return CakeDecoratorGui
