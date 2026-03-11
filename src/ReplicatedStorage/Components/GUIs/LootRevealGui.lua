--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--packages
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
-- local LootTable = require(ReplicatedStorage.Common.GameInfo.LootTable)
local SoundUtils = require(ReplicatedStorage.NonWallyPackages.SoundUtils)

--Constants
local REVEAL_SPEED = 0.45
local ITEM_ANIM_SPEED = 0.6
local WINDOW_ANIM_SPEED = 0.8
local COMPLETION_RIPPLE_SPEED = 0.05 -- NEW: Speed between each item bouncing at the end

-- Sounds
local SoundPop = SoundUtils.MakeSound("rbxassetid://4612375233", script)
local SoundComplete = SoundUtils.MakeSound("rbxassetid://93939855588300", script)
local SoundOpen = SoundUtils.MakeSound("rbxassetid://12222200", script)

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

	gui.Enabled = true
end

function LootRevealGui:Start()
	-- Optional: Listen for a RemoteEvent here to trigger the reveal automatically
end

function LootRevealGui:Stop()
	self._Trove:Clean()
end

-- // PUBLIC API \\ --

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

function LootRevealGui:_AnimateSequence(itemsToGive)
	-- 1. Reset UI Container
	self:_CleanContainer()
	self._ScrollingFrame.CanvasPosition = Vector2.new(0, 0)

	-- 2. Open Window
	self._MainFrame.Visible = true
	self._MainFrame.Size = UDim2.fromScale(0, 0)

	local openInfo = TweenInfo.new(WINDOW_ANIM_SPEED, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	TweenService:Create(self._MainFrame, openInfo, { Size = self._DefaultSize }):Play()

	-- Play the open sound effect precisely as the GUI starts tweening
	SoundOpen:Play()

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

		local data = LootTable[itemKey]
		if not data then
			continue
		end

		self:_SpawnItem(data, index)
		task.wait(REVEAL_SPEED)
	end

	-- 4. Finish
	if self._IsOpen then
		SoundComplete:Play()
		self:_PlayCompletionAnimation() -- NEW: Trigger the celebratory animation
	end
end

-- NEW: The celebratory completion animation logic
function LootRevealGui:_PlayCompletionAnimation()
	-- Create a bouncy "pop" effect for the entire main container
	-- We multiply the default scale/offset by 1.05 for a 5% size increase
	local enlargedSize = UDim2.new(
		self._DefaultSize.X.Scale * 1.05,
		self._DefaultSize.X.Offset,
		self._DefaultSize.Y.Scale * 1.05,
		self._DefaultSize.Y.Offset
	)

	-- The 'true' at the end of TweenInfo makes it reverse back to normal automatically!
	local mainPopInfo = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true)
	TweenService:Create(self._MainFrame, mainPopInfo, { Size = enlargedSize, Rotation = 2 }):Play()

	-- Send a ripple animation through the revealed items
	task.spawn(function()
		for _, child in ipairs(self._ScrollingFrame:GetChildren()) do
			if not self._IsOpen then
				break
			end -- Stop if they close it during the ripple

			-- Make sure we are only grabbing our item holders
			if child:IsA("Frame") and string.sub(child.Name, 1, 7) == "Holder_" then
				local itemFrame = child:FindFirstChildWhichIsA("Frame")
				if itemFrame then
					-- Make the individual item pop out 15% larger and snap back
					local itemPopInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
					TweenService:Create(itemFrame, itemPopInfo, { Size = UDim2.fromScale(1.15, 1.15) }):Play()

					-- Wait slightly before bouncing the next one
					task.wait(COMPLETION_RIPPLE_SPEED)
				end
			end
		end

		-- Just to be perfectly safe, ensure the main frame resets rotation
		if self._IsOpen then
			TweenService:Create(self._MainFrame, TweenInfo.new(0.1), { Rotation = 0 }):Play()
		end
	end)
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

	SoundOpen:Play()

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
