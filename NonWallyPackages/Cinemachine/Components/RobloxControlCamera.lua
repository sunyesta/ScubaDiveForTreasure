local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Trackball = require(script.Parent.Trackball)

-- [BODY/AIM] RobloxControlCamera
-- Inherits from Trackball. Adds functionality to rotate the character when fully zoomed in,
-- toggles mouse lock with Shift (if enabled in settings), and applies a camera offset.
local RobloxControlCamera = setmetatable({}, Trackball)
RobloxControlCamera.__index = RobloxControlCamera

function RobloxControlCamera.new(config)
	-- Initialize the Trackball base
	local self = Trackball.new(config)
	setmetatable(self, RobloxControlCamera)

	self.IsShiftLocked = false
	self.ShiftLockOffset = 2 -- Default offset distance (studs)
	self.EnableShiftLock = if config.EnableShiftLock == nil then true else config.EnableShiftLock
	self.RotatePlayerWithShiftlock = if config.RotatePlayerWithShiftlock == nil
		then true
		else config.RotatePlayerWithShiftlock

	-- We track the vector we added last frame so we can subtract it this frame.
	-- This allows us to treat self.FollowOffset as the source of truth,
	-- enabling external updates to FollowOffset to work correctly.
	self._lastShiftOffsetVector = Vector3.new(0, 0, 0)

	-- Helper to check if Shift Lock is enabled in Roblox settings
	local function isShiftLockSettingEnabled()
		return UserGameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch
	end

	-- 1. Input listener for Shift Lock toggle via Trove
	self._trove:Connect(UserInputService.InputBegan, function(input, processed)
		-- We avoid checking 'processed' here because Roblox's default scripts
		-- (like the ControlModule) often consume the Shift key input.

		-- However, we must ensure we aren't typing in a text box.
		if UserInputService:GetFocusedTextBox() then
			return
		end

		-- Support both Left and Right Shift
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			-- Only toggle if the setting is actually enabled AND allowed by config
			if self.EnableShiftLock and isShiftLockSettingEnabled() then
				self.IsShiftLocked = not self.IsShiftLocked
			end
		end
	end)

	-- 2. Watch for Settings Changes
	-- If the user goes into the ESC menu and disables Shift Lock Switch, we must turn off our lock.
	self._trove:Connect(UserGameSettings:GetPropertyChangedSignal("ControlMode"), function()
		if not isShiftLockSettingEnabled() then
			self.IsShiftLocked = false
		end
	end)

	return self
end

function RobloxControlCamera:Mutate(vcam, state, dt)
	local isFullyZoomed = self.TargetDistance <= (self.MinDistance + 0.1)

	-- 1. Handle Shift Lock State
	-- We temporarily enable MouseLock on the base instance if ShiftLock is active.
	local originalMouseLock = self.MouseLock
	if self.IsShiftLocked then
		self.MouseLock = true
	end

	-- 2. Handle Camera Offset (Shift Lock shoulder view)
	-- Instead of relying on a stale BaseFollowOffset, we recover the current 'Base'
	-- by subtracting the shift offset we applied in the PREVIOUS frame.
	-- This respects external changes to self.FollowOffset.
	local currentBaseOffset = self.FollowOffset - self._lastShiftOffsetVector

	-- Calculate the new shift offset using the OLD Yaw (before Trackball updates it)
	local oldYaw = self.Yaw
	local targetShiftVector = Vector3.new(0, 0, 0)

	if self.IsShiftLocked and not isFullyZoomed then
		local camRightVector = CFrame.Angles(0, oldYaw, 0).RightVector
		targetShiftVector = camRightVector * self.ShiftLockOffset
	end

	-- Apply the new total offset
	self.FollowOffset = currentBaseOffset + targetShiftVector
	self._lastShiftOffsetVector = targetShiftVector

	-- 3. Run standard Trackball logic
	-- This handles Input, Damping, Collision, and Position.
	-- It updates self.Yaw to the NEW Yaw.
	Trackball.Mutate(self, vcam, state, dt)

	-- Restore configuration
	self.MouseLock = originalMouseLock

	-- 4. JITTER FIX: Offset Correction
	-- Since Trackball.Mutate updated self.Yaw, our FollowOffset (calculated with oldYaw) is now stale.
	-- This causes the camera to wobble because it's rotating to NewYaw but pivoting around OldYaw's offset.
	if self.IsShiftLocked and not isFullyZoomed then
		local newYaw = self.Yaw

		-- Recalculate what the offset SHOULD be with the new rotation
		local camRightVectorNew = CFrame.Angles(0, newYaw, 0).RightVector
		local correctShiftVector = camRightVectorNew * self.ShiftLockOffset
		local correctTotalOffset = currentBaseOffset + correctShiftVector

		-- Calculate the difference
		local diff = correctTotalOffset - self.FollowOffset

		-- Apply the difference to the final calculated position to snap it to the correct pivot
		state.Position = state.Position + diff

		-- Update internal state for next frame consistency
		self.FollowOffset = correctTotalOffset
		self._lastShiftOffsetVector = correctShiftVector
	end

	-- 5. Character Rotation
	-- Rotate character if Shift Locked OR First Person
	local target = vcam.Follow
	local player = Players.LocalPlayer

	-- MODIFIED: Now respects RotatePlayerWithShiftlock configuration
	local shouldForceRotate = isFullyZoomed or (self.IsShiftLocked and self.RotatePlayerWithShiftlock)
	if player and player.Character and target then
		-- Check if the camera target is the player's character
		if target == player.Character or target:IsDescendantOf(player.Character) then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				if shouldForceRotate then
					-- Manual Rotation

					humanoid.AutoRotate = false
					-- We construct the CFrame at the current position with the NEW Yaw
					-- This aligns the character perfectly with the camera's new rotation
					local currentPos = rootPart.Position
					local newCFrame = CFrame.new(currentPos) * CFrame.Angles(0, self.Yaw, 0)
					rootPart.CFrame = newCFrame
				else
					if self.IsShiftLocked then
						humanoid.AutoRotate = false
					else
						humanoid.AutoRotate = true
					end
				end
			end
		end
	end
end

return RobloxControlCamera
