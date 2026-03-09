--!strict
-- This script runs on the Server/Studio context and handles the step-by-step Move Tool logic.
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local MoveTool = {}

-- Constructs the Move Tool section and returns the assembled CanvasGroup
function MoveTool.Create(): CanvasGroup
	-- 1. Create the Section Outline
	local section, body = Constructors.CreateSection("Move Tool", ICONS.Layout, THEME.Indigo)

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingTop = UDim.new(0, 16)
	bodyPadding.PaddingBottom = UDim.new(0, 16)
	bodyPadding.PaddingLeft = UDim.new(0, 16)
	bodyPadding.PaddingRight = UDim.new(0, 16)
	bodyPadding.Parent = body

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 12)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = body

	-- 2. Create the Status TextLabel
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "select instance"
	statusLabel.TextColor3 = THEME.TextMain
	statusLabel.Font = Enum.Font.BuilderSansMedium
	statusLabel.TextSize = 16
	statusLabel.LayoutOrder = 1
	statusLabel.Parent = body

	-- 3. Create the OK Button (For 2-step moving)
	local okBtn = Instance.new("TextButton")
	okBtn.Name = "OKButton"
	okBtn.Size = UDim2.new(1, 0, 0, 44)
	okBtn.BackgroundColor3 = THEME.Indigo
	okBtn.Text = "OK"
	okBtn.TextColor3 = Color3.new(1, 1, 1)
	okBtn.Font = Enum.Font.BuilderSansBold
	okBtn.TextSize = 14
	okBtn.LayoutOrder = 2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = okBtn

	okBtn.Parent = body

	-- Hover Effects for OK Button
	okBtn.MouseEnter:Connect(function()
		okBtn.BackgroundColor3 = THEME.Blue
	end)
	okBtn.MouseLeave:Connect(function()
		okBtn.BackgroundColor3 = THEME.Indigo
	end)

	-- 4. Create the Quick "Move to Workspace" Button
	local workspaceBtn = Instance.new("TextButton")
	workspaceBtn.Name = "WorkspaceButton"
	workspaceBtn.Size = UDim2.new(1, 0, 0, 44)
	workspaceBtn.BackgroundColor3 = THEME.Emerald -- Giving it a distinct color
	workspaceBtn.Text = "Move to Workspace"
	workspaceBtn.TextColor3 = Color3.new(1, 1, 1)
	workspaceBtn.Font = Enum.Font.BuilderSansBold
	workspaceBtn.TextSize = 14
	workspaceBtn.LayoutOrder = 3 -- Places it below the OK button

	local wsCorner = Instance.new("UICorner")
	wsCorner.CornerRadius = UDim.new(0, 12)
	wsCorner.Parent = workspaceBtn

	workspaceBtn.Parent = body

	-- Hover Effects for Workspace Button
	workspaceBtn.MouseEnter:Connect(function()
		-- Slightly lighten the emerald color on hover
		local h, s, v = THEME.Emerald:ToHSV()
		workspaceBtn.BackgroundColor3 = Color3.fromHSV(h, s, math.clamp(v + 0.1, 0, 1))
	end)
	workspaceBtn.MouseLeave:Connect(function()
		workspaceBtn.BackgroundColor3 = THEME.Emerald
	end)

	-- 5. Setup State Machine Logic
	local step = 1
	local instancesToMove: { Instance } = {}

	-- Helper function to reset UI back to default state
	local function resetTool()
		step = 1
		instancesToMove = {}
		statusLabel.Text = "select instance"
		statusLabel.TextColor3 = THEME.TextMain
		okBtn.Visible = true
		workspaceBtn.Visible = true
	end

	-- Logic for the standard 2-step move process
	okBtn.Activated:Connect(function()
		local selected = Selection:Get()

		if step == 1 then
			-- Step 1: User is confirming what they want to move
			if #selected == 0 then
				warn("[Random Studio Tools] Please select at least one instance to move!")
				return
			end

			instancesToMove = selected
			step = 2
			statusLabel.Text = "select parent"
		elseif step == 2 then
			-- Step 2: User is confirming where it should go
			if #selected ~= 1 then
				warn("[Random Studio Tools] Please select exactly ONE instance to be the new parent!")
				return
			end

			local targetParent = selected[1]

			-- Set waypoint so we can easily Undo (Ctrl + Z) this action
			ChangeHistoryService:SetWaypoint("BeforeMoveTool")

			local successCount = 0
			for _, inst in ipairs(instancesToMove) do
				-- Guard check to ensure we don't accidentally parent an object to itself or its children
				if inst ~= targetParent and not targetParent:IsDescendantOf(inst) then
					inst.Parent = targetParent
					successCount += 1
				else
					warn(
						string.format(
							"[Random Studio Tools] Skipped %s: Cannot parent an instance to itself or its descendant.",
							inst.Name
						)
					)
				end
			end

			ChangeHistoryService:SetWaypoint("AfterMoveTool")

			-- Update UI to success state
			if successCount > 0 then
				statusLabel.Text = "Moved instance"
				statusLabel.TextColor3 = THEME.Emerald -- Flash it green for visual success feedback
			else
				statusLabel.Text = "Move failed"
				statusLabel.TextColor3 = THEME.Orange
			end

			step = 3
			okBtn.Visible = false -- Hide the buttons temporarily
			workspaceBtn.Visible = false

			-- Step 3: Wait 2 seconds, then revert to initial state
			task.delay(2, function()
				resetTool()
			end)
		end
	end)

	-- Logic for the quick "Move to Workspace" button
	workspaceBtn.Activated:Connect(function()
		-- We always want to grab the currently selected items, regardless of the "step"
		local selected = Selection:Get()

		if #selected == 0 then
			warn("[Random Studio Tools] Please select at least one instance to move to Workspace!")
			return
		end

		ChangeHistoryService:SetWaypoint("BeforeMoveToWorkspace")

		local successCount = 0
		for _, inst in ipairs(selected) do
			-- We just need to make sure they didn't somehow select the workspace itself
			if inst ~= workspace then
				inst.Parent = workspace
				successCount += 1
			end
		end

		ChangeHistoryService:SetWaypoint("AfterMoveToWorkspace")

		if successCount > 0 then
			statusLabel.Text = "Moved to Workspace!"
			statusLabel.TextColor3 = THEME.Emerald
		else
			statusLabel.Text = "Move failed"
			statusLabel.TextColor3 = THEME.Orange
		end

		-- Hide buttons temporarily and reset after 2 seconds
		okBtn.Visible = false
		workspaceBtn.Visible = false

		task.delay(2, function()
			resetTool()
		end)
	end)

	return section
end

return MoveTool
