--!strict
-- This script runs on the Server/Studio context and handles converting SpecialMeshes to MeshParts.
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local InsertService = game:GetService("InsertService")

local Config = require(script.Parent.Parent.Config)
local Constructors = require(script.Parent.Parent.Constructors)

local THEME = Config.THEME
local ICONS = Config.ICONS

local SpecialMeshConverter = {}

-- Constructs the SpecialMesh Converter section and returns the assembled CanvasGroup
function SpecialMeshConverter.Create(): CanvasGroup
	-- 1. Create the Section Outline
	local section, body = Constructors.CreateSection("SpecialMesh to MeshPart", ICONS.Replace, THEME.Orange)

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

	-- 2. Create the Information Label
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.new(1, 0, 0, 0)
	infoLabel.AutomaticSize = Enum.AutomaticSize.Y
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text =
		"Select Parts containing a SpecialMesh (or the SpecialMeshes directly) to convert them into modern MeshParts."
	infoLabel.TextColor3 = THEME.TextMuted
	infoLabel.Font = Enum.Font.BuilderSans
	infoLabel.TextSize = 13
	infoLabel.TextWrapped = true
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.LayoutOrder = 1
	infoLabel.Parent = body

	-- 3. Create the Execution Button
	local convertBtn = Instance.new("TextButton")
	convertBtn.Name = "ConvertButton"
	convertBtn.Size = UDim2.new(1, 0, 0, 44)
	convertBtn.BackgroundColor3 = THEME.Orange
	convertBtn.Text = "Convert Selected"
	convertBtn.TextColor3 = Color3.new(1, 1, 1)
	convertBtn.Font = Enum.Font.BuilderSansMedium
	convertBtn.TextSize = 14
	convertBtn.LayoutOrder = 2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = convertBtn

	convertBtn.Parent = body

	-- Hover Effects
	convertBtn.MouseEnter:Connect(function()
		local h, s, v = THEME.Orange:ToHSV()
		convertBtn.BackgroundColor3 = Color3.fromHSV(h, s, math.clamp(v + 0.1, 0, 1))
	end)
	convertBtn.MouseLeave:Connect(function()
		convertBtn.BackgroundColor3 = THEME.Orange
	end)

	-- 4. Setup the Logic
	convertBtn.Activated:Connect(function()
		local selectedInstances = Selection:Get()

		if #selectedInstances == 0 then
			warn("[Random Studio Tools] Please select at least one SpecialMesh or Part containing a SpecialMesh!")
			return
		end

		ChangeHistoryService:SetWaypoint("BeforeSpecialMeshConversion")

		local newSelection = {}
		local successCount = 0

		for _, instance in ipairs(selectedInstances) do
			local targetPart: BasePart? = nil
			local specialMesh: SpecialMesh? = nil

			-- Identify if they selected the Part or the SpecialMesh itself
			if instance:IsA("BasePart") then
				specialMesh = instance:FindFirstChildWhichIsA("SpecialMesh")
				if specialMesh then
					targetPart = instance
				end
			elseif instance:IsA("SpecialMesh") then
				specialMesh = instance
				if instance.Parent and instance.Parent:IsA("BasePart") then
					targetPart = instance.Parent
				end
			end

			if targetPart and specialMesh and specialMesh.MeshId ~= "" then
				-- Attempt to create the new MeshPart
				local success, newMeshPart = pcall(function()
					return InsertService:CreateMeshPartAsync(
						specialMesh.MeshId,
						Enum.CollisionFidelity.Default,
						Enum.RenderFidelity.Automatic
					)
				end)

				if success and newMeshPart then
					-- Copy properties from the original part
					newMeshPart.Name = targetPart.Name
					newMeshPart.Color = targetPart.Color
					newMeshPart.Material = targetPart.Material
					newMeshPart.MaterialVariant = targetPart.MaterialVariant
					newMeshPart.Transparency = targetPart.Transparency
					newMeshPart.Reflectance = targetPart.Reflectance
					newMeshPart.CastShadow = targetPart.CastShadow

					newMeshPart.Anchored = targetPart.Anchored
					newMeshPart.CanCollide = targetPart.CanCollide
					newMeshPart.CanQuery = targetPart.CanQuery
					newMeshPart.CanTouch = targetPart.CanTouch
					newMeshPart.Massless = targetPart.Massless
					newMeshPart.CollisionGroup = targetPart.CollisionGroup

					-- Apply SpecialMesh transformations
					newMeshPart.TextureID = specialMesh.TextureId
					-- A SpecialMesh's visual size is the Part's size multiplied by the mesh scale
					newMeshPart.Size = targetPart.Size * specialMesh.Scale
					-- Offset the CFrame if the SpecialMesh had an offset
					newMeshPart.CFrame = targetPart.CFrame * CFrame.new(specialMesh.Offset)

					-- Move all other children over to the new MeshPart
					for _, child in ipairs(targetPart:GetChildren()) do
						if child ~= specialMesh then
							child.Parent = newMeshPart
						end
					end

					-- Swap them in the workspace
					newMeshPart.Parent = targetPart.Parent
					table.insert(newSelection, newMeshPart)

					targetPart:Destroy()
					successCount += 1
				else
					warn("[Random Studio Tools] Failed to generate MeshPart for ID:", specialMesh.MeshId)
					table.insert(newSelection, instance) -- Keep original in selection if failed
				end
			else
				-- Not a valid conversion target, keep in selection
				table.insert(newSelection, instance)
			end
		end

		Selection:Set(newSelection)
		ChangeHistoryService:SetWaypoint("AfterSpecialMeshConversion")

		if successCount > 0 then
			print(
				string.format(
					"[Random Studio Tools] Successfully converted %d SpecialMesh(es) to MeshPart(s)!",
					successCount
				)
			)
		else
			warn("[Random Studio Tools] No valid SpecialMeshes were found to convert.")
		end
	end)

	return section
end

return SpecialMeshConverter
