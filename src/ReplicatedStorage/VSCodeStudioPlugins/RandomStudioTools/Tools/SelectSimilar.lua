--!strict
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local SelectSimilar = {}

-- A quick helper function to keep our buttons consistent with the plugin's theme
local function CreateButton(name: string, text: string, order: number, parent: Instance): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.BackgroundColor3 = THEME.PanelHeader
	btn.Text = text
	btn.TextColor3 = THEME.TextMain
	btn.Font = Enum.Font.BuilderSansMedium
	btn.TextSize = 14
	btn.LayoutOrder = order

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Border
	stroke.Parent = btn

	btn.Parent = parent

	-- Hover Effects
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = THEME.ButtonHoverBg
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = THEME.PanelHeader
	end)

	return btn
end

-- Constructs the Select Similar section and returns the assembled CanvasGroup
function SelectSimilar.Create(): CanvasGroup
	-- 1. Create the Section Outline (Reusing the Search icon and giving it the Indigo theme)
	local section, body = Constructors.CreateSection("Select Similar", ICONS.Search, THEME.Indigo)

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingTop = UDim.new(0, 16)
	bodyPadding.PaddingBottom = UDim.new(0, 16)
	bodyPadding.PaddingLeft = UDim.new(0, 16)
	bodyPadding.PaddingRight = UDim.new(0, 16)
	bodyPadding.Parent = body

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 8) -- Space between the buttons
	listLayout.Parent = body

	-- 2. Create the buttons
	local colorBtn = CreateButton("ColorBtn", "Select by Color", 1, body)
	local meshBtn = CreateButton("MeshBtn", "Select by Mesh ID", 2, body)
	local surfaceBtn = CreateButton("SurfaceBtn", "Select by Surface Appearance", 3, body)
	local nameBtn = CreateButton("NameBtn", "Select by Name", 4, body)
	local beamBtn = CreateButton("BeamBtn", "Select Beams in Selection", 5, body)

	-- Helper function to find the target value from the user's current selection (Used for single-target buttons)
	local function GetFirstValid(validationFunc: (Instance) -> any): any?
		local selected = Selection:Get()
		for _, inst in ipairs(selected) do
			local val = validationFunc(inst)
			if val ~= nil then
				return val
			end
		end
		return nil
	end

	-- 3. Logic for "Select by Color"
	colorBtn.Activated:Connect(function()
		-- Find the color of the first valid BasePart selected
		local targetColor = GetFirstValid(function(inst)
			if inst:IsA("BasePart") then
				return inst.Color
			end
			return nil
		end)

		if not targetColor then
			warn("[Random Studio Tools] Please select a BasePart with a Color first!")
			return
		end

		local newSelection = {}
		-- Scan Workspace for parts with the matching Color3
		for _, inst in ipairs(Workspace:GetDescendants()) do
			if inst:IsA("BasePart") and inst.Color == targetColor then
				table.insert(newSelection, inst)
			end
		end

		Selection:Set(newSelection)
		print(string.format("[Random Studio Tools] Selected %d parts matching the Color.", #newSelection))
	end)

	-- 4. Logic for "Select by Mesh ID" (UPDATED FOR MULTIPLE SELECTIONS)
	meshBtn.Activated:Connect(function()
		local currentSelection = Selection:Get()

		-- We will store all the unique MeshIds we find in this dictionary
		-- Dictionaries are extremely fast for looking up values later!
		local targetIds: { [string]: boolean } = {}
		local hasTarget = false

		-- Gather all MeshIds from the currently selected objects
		for _, inst in ipairs(currentSelection) do
			if inst:IsA("MeshPart") and inst.MeshId ~= "" then
				targetIds[inst.MeshId] = true
				hasTarget = true
			elseif inst:IsA("BasePart") then
				local specialMesh = inst:FindFirstChildWhichIsA("SpecialMesh")
				if specialMesh and specialMesh.MeshId ~= "" then
					targetIds[specialMesh.MeshId] = true
					hasTarget = true
				end
			end
		end

		if not hasTarget then
			warn("[Random Studio Tools] Please select at least one MeshPart or a part containing a SpecialMesh first!")
			return
		end

		local newSelection = {}

		-- Scan Workspace and check if the found mesh's ID exists in our targetIds dictionary
		for _, inst in ipairs(Workspace:GetDescendants()) do
			if inst:IsA("MeshPart") then
				if targetIds[inst.MeshId] then
					table.insert(newSelection, inst)
				end
			elseif inst:IsA("BasePart") then
				local specialMesh = inst:FindFirstChildWhichIsA("SpecialMesh")
				if specialMesh and targetIds[specialMesh.MeshId] then
					table.insert(newSelection, inst)
				end
			end
		end

		Selection:Set(newSelection)
		print(string.format("[Random Studio Tools] Selected %d parts matching the selected Mesh IDs.", #newSelection))
	end)

	-- 5. Logic for "Select by Surface Appearance"
	surfaceBtn.Activated:Connect(function()
		-- Look for a part that contains a SurfaceAppearance
		local targetMap = GetFirstValid(function(inst)
			local sa = inst:FindFirstChildWhichIsA("SurfaceAppearance")
			if sa then
				return sa.ColorMap
			end
			return nil
		end)

		if not targetMap or targetMap == "" then
			warn("[Random Studio Tools] Please select a part containing a SurfaceAppearance with a valid ColorMap!")
			return
		end

		local newSelection = {}
		-- Scan Workspace for SurfaceAppearances that use the exact same ColorMap texture
		for _, inst in ipairs(Workspace:GetDescendants()) do
			if inst:IsA("BasePart") then
				local sa = inst:FindFirstChildWhichIsA("SurfaceAppearance")
				if sa and sa.ColorMap == targetMap then
					table.insert(newSelection, inst)
				end
			end
		end

		Selection:Set(newSelection)
		print(string.format("[Random Studio Tools] Selected %d parts matching the Surface Appearance.", #newSelection))
	end)

	-- 6. Logic for "Select by Name"
	nameBtn.Activated:Connect(function()
		-- Any instance has a Name, so we just grab the Name of the first selected item
		local targetName = GetFirstValid(function(inst)
			return inst.Name
		end)

		if not targetName then
			warn("[Random Studio Tools] Please select an Instance to match by name first!")
			return
		end

		local newSelection = {}
		-- Scan Workspace for instances with the exact same name
		for _, inst in ipairs(Workspace:GetDescendants()) do
			if inst.Name == targetName then
				table.insert(newSelection, inst)
			end
		end

		Selection:Set(newSelection)
		print(string.format("[Random Studio Tools] Selected %d instances named '%s'.", #newSelection, targetName))
	end)

	-- 7. Logic for "Select Beams in Selection"
	beamBtn.Activated:Connect(function()
		local currentSelection = Selection:Get()

		if #currentSelection == 0 then
			warn("[Random Studio Tools] Please select some models or parts to search for beams first!")
			return
		end

		local newSelection = {}

		-- We only search inside what the user currently has selected
		for _, inst in ipairs(currentSelection) do
			-- If they directly selected a Beam, we should keep it
			if inst:IsA("Beam") then
				table.insert(newSelection, inst)
			end

			-- Look for any Beams parented inside the selected models/parts
			for _, descendant in ipairs(inst:GetDescendants()) do
				if descendant:IsA("Beam") then
					table.insert(newSelection, descendant)
				end
			end
		end

		-- This overwrites the previous selection, effectively deselecting everything else
		Selection:Set(newSelection)
		print(string.format("[Random Studio Tools] Selected %d Beams from the current selection.", #newSelection))
	end)

	return section
end

return SelectSimilar
