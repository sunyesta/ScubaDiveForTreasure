--!strict
-- This script runs on the Server/Studio context and handles the Auto Primary Part UI and logic.
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local AutoPrimaryPart = {}

-- Constructs the Auto Primary Part section and returns the assembled CanvasGroup
function AutoPrimaryPart.Create(): CanvasGroup
	-- 1. Create the Section Outline using our universal constructor
	local section, body = Constructors.CreateSection("Auto Primary Part", ICONS.Settings, THEME.Emerald)

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingTop = UDim.new(0, 16)
	bodyPadding.PaddingBottom = UDim.new(0, 16)
	bodyPadding.PaddingLeft = UDim.new(0, 16)
	bodyPadding.PaddingRight = UDim.new(0, 16)
	bodyPadding.Parent = body

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = body

	-- 2. Create the Execution Button
	local executeBtn = Instance.new("TextButton")
	executeBtn.Name = "ExecuteButton"
	executeBtn.Size = UDim2.new(1, 0, 0, 48)
	executeBtn.BackgroundColor3 = THEME.Emerald
	executeBtn.Text = "Set Largest Part as Primary"
	executeBtn.TextColor3 = Color3.new(1, 1, 1)
	executeBtn.Font = Enum.Font.BuilderSansMedium
	executeBtn.TextSize = 14

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = executeBtn

	executeBtn.Parent = body

	-- 3. Setup the Logic
	executeBtn.Activated:Connect(function()
		local selectedInstances = Selection:Get()

		if #selectedInstances == 0 then
			warn("[Random Studio Tools] Please select at least one Model!")
			return
		end

		-- Create a waypoint so the user can 'Ctrl + Z' to undo this action
		ChangeHistoryService:SetWaypoint("BeforeAutoPrimaryPart")

		local modelsUpdated = 0

		-- Loop through the current selection
		for _, instance in ipairs(selectedInstances) do
			if instance:IsA("Model") then
				local biggestPart: BasePart? = nil
				local maxVolume = 0

				-- Search through all descendants to find BaseParts
				for _, desc in ipairs(instance:GetDescendants()) do
					if desc:IsA("BasePart") then
						-- Calculate volume: width * height * depth
						local volume = desc.Size.X * desc.Size.Y * desc.Size.Z

						-- Compare against our current maximum
						if volume > maxVolume then
							maxVolume = volume
							biggestPart = desc
						end
					end
				end

				-- If we successfully found a part, assign it as the PrimaryPart
				if biggestPart then
					instance.PrimaryPart = biggestPart
					modelsUpdated += 1
				end
			end
		end

		-- Close the waypoint to complete the undo history state
		ChangeHistoryService:SetWaypoint("AfterAutoPrimaryPart")

		if modelsUpdated > 0 then
			print(
				string.format("[Random Studio Tools] Successfully set the PrimaryPart for %d Model(s)!", modelsUpdated)
			)
		else
			warn("[Random Studio Tools] No valid BaseParts found inside the selected Models.")
		end
	end)

	return section
end

return AutoPrimaryPart
