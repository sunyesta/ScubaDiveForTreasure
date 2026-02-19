--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local LootTable = require(ReplicatedStorage.Common.GameInfo.LootTable)
local SoundUtils = require(ReplicatedStorage.NonWallyPackages.SoundUtils)
-- Assuming LootTable is a module returning the table structure from your example
-- local LootTable = require(ReplicatedStorage.Common.GameInfo.LootTable)

--Constants
local REVEAL_SPEED = 0.45
local ITEM_ANIM_SPEED = 0.6
local WINDOW_ANIM_SPEED = 0.8

local SoundPop = SoundUtils.MakeSound("rbxassetid://4612375233", script)
local SoundComplete = SoundUtils.MakeSound("rbxassetid://12222200", script)

local Player = Players.LocalPlayer

local LootRevealGui = Component.new({
	Tag = "LootRevealGui",
	Ancestors = { Player },
})

-- // COMPONENT LIFECYCLE \\ --

function LootRevealGui:Construct()
	self._Trove = Trove.new()
	self._OpenTrove = self._Trove:Extend()

	-- Cache UI References
	-- Assuming the Instance tagged is the ScreenGui or the Main Frame
	local gui = self.Instance
	self._MainFrame = gui:WaitForChild("Container")
	self._ScrollingFrame = self._MainFrame:WaitForChild("ScrollingFrame")
	self._LootTemplate = self._ScrollingFrame:WaitForChild("LootFrame")
	self._ListLayout = self._ScrollingFrame:FindFirstChildOfClass("UIListLayout")
	self._CloseButton = self._MainFrame:WaitForChild("CloseButton")

	-- Setup initial state
	self._DefaultSize = self._MainFrame.Size
	self._LootTemplate.Parent = nil -- Hide template
	self._MainFrame.Visible = false

	if self._ListLayout then
		self._ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end
end

function LootRevealGui:Start()
	-- Optional: Listen for a RemoteEvent here to trigger the reveal automatically
	-- Example:
	-- self._Trove:Connect(Remotes.Client:OnEvent("LootDrop"), function(items) self:Reveal(items) end)
end

function LootRevealGui:Stop()
	self._Trove:Clean()
end

-- // PUBLIC API \\ --

-- Call this to start the sequence
-- Usage: LootRevealGui.DisplayLoot({"Rock", "Necklace"})
function LootRevealGui.DisplayLoot(itemsToGive)
	local self = LootRevealGui:GetAll()[1]
	if not self then
		return
	end

	-- Close any existing window first to reset
	self:_CloseInternal()

	self._OpenTrove:Add(self._CloseButton.MouseButton1Click:Connect(function()
		if self._IsOpen then
			self:_CloseInternal()
		end
	end))

	-- Start the sequence
	task.spawn(function()
		self:_AnimateSequence(itemsToGive)
		self._CloseButton.Visible = true
	end)
end

-- // INTERNAL METHODS \\ --

--! Yeilds
function LootRevealGui:_AnimateSequence(itemsToGive)
	-- 1. Reset UI Container
	self:_CleanContainer()
	self._ScrollingFrame.CanvasPosition = Vector2.new(0, 0)

	-- 2. Open Window
	self._MainFrame.Visible = true
	self._MainFrame.Size = UDim2.fromScale(0, 0)

	local openInfo = TweenInfo.new(WINDOW_ANIM_SPEED, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	TweenService:Create(self._MainFrame, openInfo, { Size = self._DefaultSize }):Play()

	-- Track this open session
	self._IsOpen = true

	task.wait(0.4)
	if not self._IsOpen then
		return
	end -- Check if closed mid-animation

	-- 3. Loop items
	for index, itemKey in ipairs(itemsToGive) do
		if not self._IsOpen then
			break
		end

		local data = LootTable[itemKey] -- Or LootTable[itemKey]
		if not data then
			continue
		end

		self:_SpawnItem(data, index)
		task.wait(REVEAL_SPEED)
	end

	-- 4. Finish
	if self._IsOpen then
		SoundComplete:Play()
	end
end

function LootRevealGui:_SpawnItem(data, index)
	-- Create Wrapper (Trove tracks it to clean up later)
	local wrapper = Instance.new("Frame")
	wrapper.Name = "Holder_" .. index
	wrapper.BackgroundTransparency = 1
	wrapper.Size = self._LootTemplate.Size
	wrapper.LayoutOrder = index
	wrapper.Parent = self._ScrollingFrame
	self._OpenTrove:Add(wrapper)

	-- Force Scroll
	self._ScrollingFrame.CanvasPosition = Vector2.new(self._ScrollingFrame.AbsoluteCanvasSize.X, 0)

	-- Create Item
	local itemFrame = self._LootTemplate:Clone()
	itemFrame.Name = data.Name
	itemFrame.BackgroundColor3 = data.RarityColor or Color3.fromRGB(50, 50, 50)

	local icon = itemFrame:FindFirstChild("ImageLabel")
	if icon then
		icon.Image = data.Icon
	end

	local text = itemFrame:FindFirstChild("TextLabel")
	if text then
		text.Text = data.Name
	end

	itemFrame.Parent = wrapper

	-- Animation Setup
	itemFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	itemFrame.Position = UDim2.fromScale(0.5, 0.5)
	itemFrame.Size = UDim2.fromScale(0, 0)
	itemFrame.Rotation = math.random(-25, 25)

	-- Play Pop
	local popInfo = TweenInfo.new(ITEM_ANIM_SPEED, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	TweenService:Create(itemFrame, popInfo, { Size = UDim2.fromScale(1, 1), Rotation = 0 }):Play()
	SoundPop:Play()
end

function LootRevealGui:_CloseInternal()
	self._IsOpen = false
	-- Animate out
	local closeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(self._MainFrame, closeInfo, { Size = UDim2.fromScale(0, 0) })
	tween:Play()
	tween.Completed:Wait()

	self._MainFrame.Visible = false
	self._CloseButton.Visible = false
	self:_CleanContainer()
	self._OpenTrove:Clean()
end

function LootRevealGui:_CleanContainer()
	for _, child in pairs(self._ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= self._LootTemplate then
			child:Destroy()
		end
	end
end

function LootRevealGui:_PlaySound(soundId)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = workspace
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 5) -- Auto destroy sound
end

return LootRevealGui
