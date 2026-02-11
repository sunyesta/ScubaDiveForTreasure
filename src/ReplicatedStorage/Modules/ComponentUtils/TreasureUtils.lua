local TreasureUtils = {}

TreasureUtils.WELD_NAME = "HoldWeld"
TreasureUtils.LOOT_LOCK_TIME = 2 -- Lowered from 30 for testing, adjust as needed

-- Helper to find where to attach the treasure on the character
function TreasureUtils.GetAttachPoint(character)
	if not character then
		return nil, nil
	end

	local attachment = character:FindFirstChild("OverheadCarryAttachment", true)
	if attachment then
		return attachment.Parent, attachment.WorldCFrame
	end

	local head = character:FindFirstChild("Head")
	if head then
		-- Default to slightly above head if no custom attachment exists
		return head, head.CFrame * CFrame.new(0, 2, 0)
	end

	return nil, nil
end

-- Shared logic to physically attach the treasure
function TreasureUtils.Attach(treasure, character)
	local rootPart = treasure.PrimaryPart
	if not rootPart or not character then
		return nil
	end

	local attachPart, attachCFrame = TreasureUtils.GetAttachPoint(character)
	if not attachPart then
		return nil
	end

	-- 1. Position the part (Visual feedback)
	rootPart.CFrame = attachCFrame

	-- 2. Clean existing welds to prevent stacking
	for _, child in pairs(rootPart:GetChildren()) do
		if child.Name == TreasureUtils.WELD_NAME and child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end

	-- 3. Create Weld
	local weld = Instance.new("WeldConstraint")
	weld.Name = TreasureUtils.WELD_NAME
	weld.Part0 = attachPart
	weld.Part1 = rootPart
	weld.Parent = rootPart -- Parent to the treasure so it cleans up with it
	weld.Enabled = true

	-- 4. Physics Properties
	rootPart.Massless = true
	rootPart.CanCollide = false
	rootPart.Anchored = false

	local hitbox = treasure:FindFirstChild("Hitbox")
	if hitbox then
		hitbox.CanCollide = false
	end

	return weld
end

-- Shared logic to physically drop the treasure
function TreasureUtils.Detach(treasure)
	local rootPart = treasure.PrimaryPart
	if not rootPart then
		return
	end

	-- 1. Disable/Destroy Weld(s)
	for _, child in pairs(rootPart:GetChildren()) do
		if child.Name == TreasureUtils.WELD_NAME and child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end

	-- 2. Restore Physics Properties
	rootPart.Massless = false
	rootPart.CanCollide = true
	rootPart.Anchored = false

	local hitbox = treasure:FindFirstChild("Hitbox")
	if hitbox then
		hitbox.CanCollide = true
	end
end

return TreasureUtils
