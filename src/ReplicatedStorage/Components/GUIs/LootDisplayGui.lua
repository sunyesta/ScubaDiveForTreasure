local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

-- Packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local LootTable = require(ReplicatedStorage.Common.GameInfo.LootTable)

-- Constants
local REVEAL_DELAY = 0.4
local TWEEN_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local POP_IN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Back)

-- Class Setup
local LootDisplayGui = Component.new({
	Tag = "LootDisplayGui",
	Ancestors = { Players.LocalPlayer },
})
LootDisplayGui.Singleton = true

-- Types
type LootItem = {
	Name: string,
	Icon: string,
	-- Add other LootTable properties here
}

function LootDisplayGui:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend() -- Sub-trove for things that exist only while open

	-- Internal State
	self.IsOpen = false
end

function LootDisplayGui:Start()
	-- UI References
	local screenGui = self.Instance :: ScreenGui
	self.MainFrame = screenGui:WaitForChild("MainFrame") :: Frame
	self.Scroller = self.MainFrame:WaitForChild("ItemsScroller") :: ScrollingFrame
	self.Sound = screenGui:WaitForChild("Sound") :: Sound

	-- Template Setup
	local originalTemplate = self.Scroller:WaitForChild("ItemCard") :: Frame
	self.CardTemplate = originalTemplate:Clone()

	-- Store original size for the "Pop in" animation
	self.MainFrameTargetSize = self.MainFrame.Size

	-- Cleanup original template and hide UI
	originalTemplate:Destroy()
	self.MainFrame.Visible = false
	self.MainFrame.Size = UDim2.fromScale(0, 0)
end

function LootDisplayGui:Stop()
	self._Trove:Clean()
end

--// Public Static API //--

function LootDisplayGui.Open()
	local self = LootDisplayGui:GetAll()[1]
	if not self then
		return
	end

	-- If already open, just return (or you could reset)
	if self.IsOpen then
		return
	end
	self.IsOpen = true

	-- Reset Visuals
	self.MainFrame.Visible = true
	self.MainFrame.Size = UDim2.fromScale(0, 0)

	-- Animate Container Pop-in
	local openTween = TweenService:Create(self.MainFrame, POP_IN_INFO, {
		Size = self.MainFrameTargetSize,
	})
	openTween:Play()

	-- Track the tween in OpenTrove so it stops if we close immediately
	self._OpenTrove:Add(function()
		openTween:Cancel()
	end)

	self._OpenTrove:Add(self.Instance.MainFrame.CloseButton.MouseButton1Click:Connect(function()
		LootDisplayGui.Close()
	end))
end

function LootDisplayGui.Close()
	local self = LootDisplayGui:GetAll()[1]
	if not self then
		return
	end

	self.IsOpen = false
	self.MainFrame.Visible = false
	self._OpenTrove:Clean() -- Destroys all displayed cards and cancels running tweens
end

function LootDisplayGui.DisplayLoot(lootNames: { string })
	task.spawn(function()
		local self = LootDisplayGui:GetAll()[1]
		assert(self, "LootDisplayGui not available")

		-- Ensure UI is open
		self.Instance.MainFrame.CloseButton.Visible = false
		LootDisplayGui.Open()

		-- Clean any previous items specifically, or rely on Close() to have cleaned them.
		-- Here we assume we append to the view. If you want a hard reset, call .Close() then .Open() first.

		task.wait(0.5) -- Brief delay after opening before items appear

		for i, itemKey in ipairs(lootNames) do
			-- Guard clause: If the UI was closed mid-loop, stop execution
			if not self.IsOpen then
				break
			end

			self:_spawnCard(itemKey, i)
			task.wait(REVEAL_DELAY)
		end

		self.Instance.MainFrame.CloseButton.Visible = true
	end)
end

--// Private Helpers //--

function LootDisplayGui:_spawnCard(itemKey: string, layoutOrder: number)
	local itemData = LootTable[itemKey]
	if not itemData then
		warn("LootDisplayGui: Missing data for", itemKey)
		return
	end

	-- Creation
	local card = self.CardTemplate:Clone()
	card.Name = itemData.Name
	card.LayoutOrder = layoutOrder

	local img = card:WaitForChild("ImageLabel") :: ImageLabel
	local txt = card:WaitForChild("TextLabel") :: TextLabel

	img.Image = itemData.Icon
	txt.Text = itemData.Name

	-- Initial Animation State
	local targetSize = self.CardTemplate.Size
	card.Size = UDim2.fromScale(0, 0)
	card.Rotation = -15
	card.BackgroundTransparency = 1
	img.ImageTransparency = 1
	txt.TextTransparency = 1

	card.Parent = self.Scroller

	-- Add to OpenTrove so it gets destroyed if .Close() is called
	self._OpenTrove:Add(card)

	-- Scroll to bottom
	self.Scroller.CanvasPosition = Vector2.new(9999, 0)

	-- Audio
	self.Sound.PlaybackSpeed = 0.9 + (layoutOrder * 0.1)
	self.Sound:Play()

	-- Animation
	local cardTween = TweenService:Create(card, TWEEN_INFO, {
		Size = targetSize,
		Rotation = 0,
		BackgroundTransparency = self.CardTemplate.BackgroundTransparency,
	})
	cardTween:Play()

	local imgTween = TweenService:Create(img, TWEEN_INFO, { ImageTransparency = 0 })
	imgTween:Play()

	local txtTween = TweenService:Create(txt, TWEEN_INFO, { TextTransparency = 0 })
	txtTween:Play()

	-- Preload
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ img })
		end)
	end)
end

return LootDisplayGui
