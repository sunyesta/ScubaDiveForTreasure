-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- Packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local InventoryController = require(ReplicatedStorage.Common.Controllers.InventoryController)
local Items = require(ReplicatedStorage.Common.GameInfo.Items)

-- Configuration (Easily adjust these!)
local CONFIG = {
	HoverScale = 1.1, -- How much the slot grows on hover
	TweenTime = 0.15, -- Speed of the animation
	DefaultTransparency = 1 - 0.3, -- Transparency for unselected slots
	DefaultColor = Color3.fromHex("FFFFFF"),
	SelectedTransparency = 1 - 0.79, -- Transparency for hovered/selected slots
	SelectedColor = Color3.fromHex("FFFFFF"),
	HoverSoundId = "rbxassetid://6895079853", -- UI Tick
	ClickSoundId = "rbxassetid://6895074211", -- UI Click/Equip
}

-- Instances
local Player = Players.LocalPlayer

local InventoryGui = Component.new({
	Tag = "InventoryGui",
	Ancestors = { Player },
})
InventoryGui.Singleton = true

function InventoryGui:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()

	self._selectedSlotIndex = nil
	self._slots = {} -- Store our slot data here

	-- Create our audio effects
	self._hoverSound = Instance.new("Sound")
	self._hoverSound.SoundId = CONFIG.HoverSoundId
	self._hoverSound.Volume = 0.3
	self._hoverSound.Parent = SoundService
	self._Trove:Add(self._hoverSound) -- Ensure Trove cleans this up later!

	self._clickSound = Instance.new("Sound")
	self._clickSound.SoundId = CONFIG.ClickSoundId
	self._clickSound.Volume = 0.5
	self._clickSound.Parent = SoundService
	self._Trove:Add(self._clickSound)
end

function InventoryGui:_buildHotbar(gui: ScreenGui)
	-- Create the main hotbar container
	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "Hotbar"
	hotbarFrame.Size = UDim2.new(0, 400, 0, 70)
	hotbarFrame.Position = UDim2.new(0.5, 0, 1, -20)
	hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
	hotbarFrame.BackgroundTransparency = 1
	hotbarFrame.Parent = gui

	-- Add a UIListLayout to automatically arrange the slots
	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.FillDirection = Enum.FillDirection.Horizontal
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.Padding = UDim.new(0, 10)
	uiListLayout.Parent = hotbarFrame

	-- Generate the slots based on the Controller's Config!
	for i = 1, InventoryController.Config.HotbarSlots do
		local slotButton = Instance.new("TextButton")
		slotButton.Name = "Slot" .. i
		slotButton.Size = UDim2.new(0, 60, 0, 60)

		-- Initial setup uses our Default configuration
		slotButton.BackgroundColor3 = CONFIG.DefaultColor
		slotButton.BackgroundTransparency = CONFIG.DefaultTransparency

		slotButton.Text = "" -- Clear default text
		slotButton.LayoutOrder = i

		-- Give the buttons nice rounded corners
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = slotButton

		-- Setup Icon ImageLabel
		local iconImage = Instance.new("ImageLabel")
		iconImage.Name = "Icon"
		iconImage.Size = UDim2.new(0.8, 0, 0.8, 0)
		iconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
		iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
		iconImage.BackgroundTransparency = 1
		iconImage.Visible = false -- Hidden by default until an item is populated
		iconImage.Parent = slotButton

		-- Setup Amount Box in the bottom right corner
		local amountBox = Instance.new("Frame")
		amountBox.Name = "AmountBox"
		amountBox.Size = UDim2.new(0, 20, 0, 20)
		amountBox.Position = UDim2.new(1, -4, 1, -4)
		amountBox.AnchorPoint = Vector2.new(1, 1)
		amountBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		amountBox.Visible = false -- Hidden by default until an item with a stack is set
		amountBox.Parent = slotButton

		local cornerBox = Instance.new("UICorner")
		cornerBox.CornerRadius = UDim.new(0, 4)
		cornerBox.Parent = amountBox

		local amountLabel = Instance.new("TextLabel")
		amountLabel.Name = "AmountLabel"
		amountLabel.Size = UDim2.new(1, 0, 1, 0)
		amountLabel.BackgroundTransparency = 1
		amountLabel.Text = ""
		amountLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
		amountLabel.Font = Enum.Font.GothamBold
		amountLabel.TextSize = 12
		amountLabel.Parent = amountBox

		slotButton.Parent = hotbarFrame
	end

	return hotbarFrame
end

function InventoryGui:Start()
	local gui: ScreenGui = self.Instance

	-- Check if the hotbar exists, if not, build it!
	local hotbarFrame = gui:FindFirstChild("Hotbar")
	if not hotbarFrame then
		hotbarFrame = self:_buildHotbar(gui)
	end

	-- Loop through the hotbar frame to find all the slot buttons
	for _, child in ipairs(hotbarFrame:GetChildren()) do
		if child:IsA("GuiButton") then
			-- Extract the slot number from the name (e.g., "Slot1" -> 1)
			local slotIndex = tonumber(string.match(child.Name, "%d+"))
			if slotIndex then
				self:_setupSlot(child, slotIndex)
			end
		end
	end

	-- Observe Inventory changes and update icons dynamically
	self._Trove:Add(InventoryController.Inventory:Observe(function(newInventory)
		self:_updateSlots(newInventory)
	end))

	-- Observe ActiveHotbarSlot changes and update UI selection
	self._Trove:Add(InventoryController.ActiveHotbarSlot:Observe(function(newActiveSlot)
		self:_updateSelectionVisuals(newActiveSlot)
	end))
end

-- Function to handle synchronizing slot visuals with Inventory State
function InventoryGui:_updateSlots(inventory)
	for index, slotData in pairs(self._slots) do
		local itemData = inventory[index]

		if itemData and itemData.ID and (itemData.Amount == nil or itemData.Amount > 0) then
			local itemTemplate = Items[itemData.ID]
			if itemTemplate and itemTemplate.Icon then
				slotData.Icon.Image = itemTemplate.Icon
				slotData.Icon.Visible = true

				-- Update Amount Visuals (Show as long as Amount is greater than 0)
				if itemData.Amount and itemData.Amount > 0 then
					slotData.AmountLabel.Text = tostring(itemData.Amount)
					slotData.AmountBox.Visible = true
				else
					slotData.AmountBox.Visible = false
				end
			else
				slotData.Icon.Visible = false
				slotData.AmountBox.Visible = false
			end
		else
			slotData.Icon.Visible = false
			slotData.AmountBox.Visible = false
		end
	end
end

-- Strictly typed internal function to set up animations and inputs for a single slot
function InventoryGui:_setupSlot(slotButton: GuiButton, index: number)
	local originalSize = slotButton.Size
	local targetHoverSize = UDim2.new(
		originalSize.X.Scale * CONFIG.HoverScale,
		originalSize.X.Offset * CONFIG.HoverScale,
		originalSize.Y.Scale * CONFIG.HoverScale,
		originalSize.Y.Offset * CONFIG.HoverScale
	)

	local tweenInfo = TweenInfo.new(CONFIG.TweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	-- Store slot data so we can access it later when changing selections or updating icons
	self._slots[index] = {
		Button = slotButton,
		Icon = slotButton:WaitForChild("Icon"),
		AmountBox = slotButton:WaitForChild("AmountBox"),
		AmountLabel = slotButton:WaitForChild("AmountBox"):WaitForChild("AmountLabel"),
		OriginalSize = originalSize,

		-- IMPLEMENTED: We now smoothly tween the BackgroundColor3 alongside Size and Transparency
		TweenHover = TweenService:Create(slotButton, tweenInfo, {
			Size = targetHoverSize,
			BackgroundTransparency = CONFIG.SelectedTransparency,
			BackgroundColor3 = CONFIG.SelectedColor, -- Smoothly shifts to the selected color
		}),
		TweenNormal = TweenService:Create(slotButton, tweenInfo, {
			Size = originalSize,
			BackgroundTransparency = CONFIG.DefaultTransparency,
			BackgroundColor3 = CONFIG.DefaultColor, -- Smoothly shifts back to the default color
		}),
	}

	-- Hook up Hover Events using Trove to prevent memory leaks
	self._Trove:Connect(slotButton.MouseEnter, function()
		if self._selectedSlotIndex ~= index then
			self._hoverSound:Play()
			self._slots[index].TweenHover:Play()
		end
	end)

	self._Trove:Connect(slotButton.MouseLeave, function()
		if self._selectedSlotIndex ~= index then
			self._slots[index].TweenNormal:Play()
		end
	end)

	-- Hook up Click Event
	self._Trove:Connect(slotButton.MouseButton1Click, function()
		self._clickSound:Play()
		InventoryController.SetHotbarIndex(index)
	end)
end

-- Function to handle visually highlighting a specific slot based on the state property
function InventoryGui:_updateSelectionVisuals(index: number?)
	-- 1. If we already had a slot selected, visually reset it
	if self._selectedSlotIndex and self._slots[self._selectedSlotIndex] then
		local oldSlot = self._slots[self._selectedSlotIndex]
		oldSlot.TweenNormal:Play() -- Shrinks back down, reverts transparency, and restores DefaultColor
	end

	-- 2. Update the visual tracker
	self._selectedSlotIndex = index

	-- 3. Visually highlight the new selected slot if it's not nil
	if index and self._slots[index] then
		local newSlot = self._slots[index]
		newSlot.TweenHover:Play() -- Scales up, changes transparency, and applies SelectedColor
	end
end

function InventoryGui:Stop()
	self._Trove:Clean()
end

function InventoryGui.Open()
	local self = InventoryGui:GetAll()[1]
	local screenGui: ScreenGui = self.Instance
	screenGui.Enabled = true
end

function InventoryGui.Close()
	local self = InventoryGui:GetAll()[1]
	local screenGui: ScreenGui = self.Instance
	screenGui.Enabled = false
	self._OpenTrove:Clean()
end

return InventoryGui
