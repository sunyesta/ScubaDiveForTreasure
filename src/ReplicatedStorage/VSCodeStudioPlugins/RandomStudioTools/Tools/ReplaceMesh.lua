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

	-- 3. Create the OK Button
	local okBtn = Instance.new("TextButton")
	okBtn.Name = "OKButton"
	okBtn.Size = UDim2.new(1, 0, 0, 44)
	okBtn.BackgroundColor3 = THEME.Blue
	okBtn.Text = "Replace Selected Meshes"
	okBtn.TextColor3 = Color3.new(1, 1, 1)
	okBtn.Font = Enum.Font.BuilderSansMedium
	okBtn.TextSize = 14
	okBtn.LayoutOrder = 2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = okBtn

	okBtn.Parent = body

	-- 4. Setup the Logic
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

					-- Copy physical and visual properties to the new MeshPart
					-- If you use a custom Reflection module, you could do something like this:
					-- for _, propName in ipairs(ReflectionService:GetProperties("MeshPart")) do
					--     pcall(function() newMeshPart[propName] = instance[propName] end)
					-- end

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
					instance:Destroy()
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
