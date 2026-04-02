local Trove = require(script.Trove)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local icon = "rbxassetid://112602100260677"
local CountDescendantsTag = "CountDescendants"
local CountDescendantsAttribute = "DescendantCount"

-- PLUGIN BUTTON

local pluginName = "CountDescendants1"
local toolbar = plugin:CreateToolbar(pluginName)

local pluginButton = toolbar:CreateButton(
	"Count Descendants1", --Text that will appear below button
	"Toggle Count Descendants1", --Text that will appear if you hover your mouse on button
	icon
) --Button icon

local trove = Trove.new()

local function countDescendantsForInst(inst: Instance)
	local instTrove = trove:Extend()
	inst:SetAttribute(CountDescendantsAttribute, #inst:GetDescendants())
	instTrove:Add(inst.DescendantAdded:Connect(function()
		if not RunService:IsRunning() then
			inst:SetAttribute(CountDescendantsAttribute, #inst:GetDescendants())
		end
	end))

	instTrove:Add(inst.DescendantRemoving:Connect(function()
		if not RunService:IsRunning() then
			inst:SetAttribute(CountDescendantsAttribute, #inst:GetDescendants())
		end
	end))

	return instTrove
end

local function startPlugin()
	print("PLUGIN STARTED")
	pluginButton:SetActive(true)
	trove:Add(function()
		pluginButton:SetActive(false)
	end)

	local runFor = CollectionService:GetTagged("CountDescendants")
	for _, inst in runFor do
		countDescendantsForInst(inst)
	end

	local troves = {}

	trove:Add(CollectionService:GetInstanceAddedSignal(CountDescendantsTag):Connect(function(inst)
		troves[inst] = countDescendantsForInst(inst)
	end))

	trove:Add(CollectionService:GetInstanceRemovedSignal(CountDescendantsTag):Connect(function(inst)
		if troves[inst] then
			troves[inst]:Clean()
			inst:SetAttribute(CountDescendantsAttribute, nil)
		end
	end))
end

local function stopPlugin()
	trove:Clean()
end

local widgetEnabled = false
pluginButton.Click:Connect(function()
	widgetEnabled = not widgetEnabled
	if widgetEnabled then
		startPlugin()
	else
		stopPlugin()
	end
end)

plugin.Unloading:Connect(function()
	stopPlugin()
end)
