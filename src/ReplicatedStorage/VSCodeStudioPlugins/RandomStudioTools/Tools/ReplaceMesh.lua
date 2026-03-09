--!strict
-- This script runs on the Server/Studio context and handles the Replace Mesh UI and logic.
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")

-- NOTE: If you have a custom community ReflectionService module, you can require it here!
-- local ReflectionService = require(game.ReplicatedStorage:WaitForChild("ReflectionService"))

local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local ReplaceMesh = {}

-- Constructs the Replace Mesh section and returns the assembled CanvasGroup
function ReplaceMesh.Create(): CanvasGroup
	-- 1. Create the Section Outline using our universal constructor
	local section, body = Constructors.CreateSection("Replace Mesh ID", ICONS.Replace, THEME.Blue)

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingTop = UDim.new(0, 16)
	bodyPadding.PaddingBottom = UDim.new(0, 16)
	bodyPadding.PaddingLeft = UDim.new(0, 16)
	bodyPadding.PaddingRight = UDim.new(0, 16)
	bodyPadding.Parent = body

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = body

	-- 2. Create the Input Field using our constructor
	local inputFieldWrap = Constructors.CreateInputField(1, "New Mesh ID", "e.g. 1234567890")
	inputFieldWrap.Parent = body

	-- Extract the actual TextBox instance so we can read its Text later
	local inputContainer = inputFieldWrap:FindFirstChild("InputContainer")
	local textBox = nil
	if inputContainer then
		textBox = inputContainer:FindFirstChild("TextBox") :: TextBox
	end

	-- 3. Create the Current Mesh ID Display (Selectable Text Box)
	local currentIdLabel = Instance.new("TextLabel")
	currentIdLabel.Size = UDim2.new(1, 0, 0, 16)
	currentIdLabel.BackgroundTransparency = 1
	currentIdLabel.Text = "Current Selected Mesh ID:"
	currentIdLabel.TextColor3 = Color3.new(1, 1, 1)
	currentIdLabel.Font = Enum.Font.BuilderSansBold
	currentIdLabel.TextSize = 14
	currentIdLabel.TextXAlignment = Enum.TextXAlignment.Left
	currentIdLabel.LayoutOrder = 2
	currentIdLabel.Parent = body

	local currentIdBox = Instance.new("TextBox")
	currentIdBox.Name = "CurrentIdBox"
	currentIdBox.Size = UDim2.new(1, 0, 0, 36)
	-- Use a dark background to indicate it's a field
	currentIdBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	currentIdBox.Text = "Select a Mesh..."
	currentIdBox.TextColor3 = Color3.new(0.6, 0.6, 0.6)
	currentIdBox.Font = Enum.Font.BuilderSans
	currentIdBox.TextSize = 14
	-- Setting TextEditable to false prevents typing but allows highlighting to copy!
	currentIdBox.TextEditable = false
	currentIdBox.ClearTextOnFocus = false
	currentIdBox.TextXAlignment = Enum.TextXAlignment.Left
	currentIdBox.LayoutOrder = 3
	currentIdBox.Parent = body

	local currentIdCorner = Instance.new("UICorner")
	currentIdCorner.CornerRadius = UDim.new(0, 8)
	currentIdCorner.Parent = currentIdBox

	local currentIdPadding = Instance.new("UIPadding")
	currentIdPadding.PaddingLeft = UDim.new(0, 12)
	currentIdPadding.PaddingRight = UDim.new(0, 12)
	currentIdPadding.Parent = currentIdBox

	-- 4. Create the OK Button
	local okBtn = Instance.new("TextButton")
	okBtn.Name = "OKButton"
	okBtn.Size = UDim2.new(1, 0, 0, 44)
	okBtn.BackgroundColor3 = THEME.Blue
	okBtn.Text = "Replace Selected Meshes"
	okBtn.TextColor3 = Color3.new(1, 1, 1)
	okBtn.Font = Enum.Font.BuilderSansMedium
	okBtn.TextSize = 14
	okBtn.LayoutOrder = 4 -- Updated LayoutOrder to sit beneath the current ID box

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = okBtn

	okBtn.Parent = body

	-- 5. Track Studio Selection to update the Current ID Box
	Selection.SelectionChanged:Connect(function()
		local selectedInstances = Selection:Get()

		if #selectedInstances == 1 then
			local inst = selectedInstances[1]
			if inst:IsA("MeshPart") or inst:IsA("SpecialMesh") then
				-- We found a valid mesh, display its ID and make text white
				currentIdBox.Text = inst.MeshId
				currentIdBox.TextColor3 = Color3.new(1, 1, 1)
			else
				-- Selected something else (like a Part or Script)
				currentIdBox.Text = "N/A (Not a Mesh)"
				currentIdBox.TextColor3 = Color3.new(0.6, 0.6, 0.6)
			end
		elseif #selectedInstances > 1 then
			currentIdBox.Text = "Multiple items selected"
			currentIdBox.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		else
			currentIdBox.Text = "Select a Mesh..."
			currentIdBox.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		end
	end)

	-- Initialize the display state manually once when the UI loads
	local initialSelection = Selection:Get()
	if #initialSelection > 0 and (initialSelection[1]:IsA("MeshPart") or initialSelection[1]:IsA("SpecialMesh")) then
		currentIdBox.Text = initialSelection[1].MeshId
		currentIdBox.TextColor3 = Color3.new(1, 1, 1)
	end

	-- 6. Setup the Replacement Logic
	okBtn.Activated:Connect(function()
		if not textBox or textBox.Text == "" then
			return
		end

		local newId = textBox.Text

		-- Quality of life: If the user just types numbers, format it into a proper rbxassetid!
		if tonumber(newId) then
			newId = "rbxassetid://" .. newId
		end

		local selectedInstances = Selection:Get()
		if #selectedInstances == 0 then
			warn("[Smoothie Move Tools] Please select at least one MeshPart to replace!")
			return
		end

		-- Create a waypoint so the user can 'Ctrl + Z' to undo this action
		ChangeHistoryService:SetWaypoint("BeforeReplaceMeshId")

		local newSelection = {}

		-- Loop through the current selection
		for _, instance in ipairs(selectedInstances) do
			if instance:IsA("MeshPart") then
				-- MeshPart.MeshId cannot be written directly. We must use InsertService to create a new one.
				local success, newMeshPart = pcall(function()
					return InsertService:CreateMeshPartAsync(newId, instance.CollisionFidelity, instance.RenderFidelity)
				end)

				if success and newMeshPart then
					-- Copy Attributes (Native to Roblox)
					for attrName, attrValue in pairs(instance:GetAttributes()) do
						newMeshPart:SetAttribute(attrName, attrValue)
					end

					-- Copy Tags (Using CollectionService)
					for _, tag in ipairs(CollectionService:GetTags(instance)) do
						CollectionService:AddTag(newMeshPart, tag)
					end

					-- Without native reflection, we explicitly copy the known properties to be safe:
					newMeshPart.Name = instance.Name
					newMeshPart.Size = instance.Size
					newMeshPart.CFrame = instance.CFrame
					newMeshPart.PivotOffset = instance.PivotOffset
					newMeshPart.Color = instance.Color
					newMeshPart.Material = instance.Material
					newMeshPart.MaterialVariant = instance.MaterialVariant
					newMeshPart.Transparency = instance.Transparency
					newMeshPart.Reflectance = instance.Reflectance
					newMeshPart.TextureID = instance.TextureID
					newMeshPart.CastShadow = instance.CastShadow

					newMeshPart.Anchored = instance.Anchored
					newMeshPart.CanCollide = instance.CanCollide
					newMeshPart.CanQuery = instance.CanQuery
					newMeshPart.CanTouch = instance.CanTouch
					newMeshPart.Massless = instance.Massless
					newMeshPart.RootPriority = instance.RootPriority
					newMeshPart.CustomPhysicalProperties = instance.CustomPhysicalProperties
					newMeshPart.CollisionGroup = instance.CollisionGroup

					-- Move all children over (like textures, attachments, scripts)
					for _, child in ipairs(instance:GetChildren()) do
						child.Parent = newMeshPart
					end

					-- Parent to the same place
					newMeshPart.Parent = instance.Parent

					-- Add to our new selection table and destroy the old one
					table.insert(newSelection, newMeshPart)
					instance.Parent = nil
				else
					warn("[Smoothie Move Tools] Failed to load new Mesh ID for MeshPart:", newId)
					table.insert(newSelection, instance) -- Keep the original in selection if it failed
				end
			elseif instance:IsA("SpecialMesh") then
				-- SpecialMeshes DO allow direct modification
				instance.MeshId = newId
				table.insert(newSelection, instance)
			else
				-- If it's neither, just keep it in the selection
				table.insert(newSelection, instance)
			end
		end

		-- Update the Studio selection to highlight our brand new MeshParts
		Selection:Set(newSelection)

		-- Close the waypoint to complete the undo history state
		ChangeHistoryService:SetWaypoint("AfterReplaceMeshId")
		print("[Smoothie Move Tools] Successfully replaced Mesh IDs!")
	end)

	return section
end

return ReplaceMesh
