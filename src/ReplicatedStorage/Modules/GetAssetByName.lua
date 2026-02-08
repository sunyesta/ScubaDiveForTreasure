local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetsByID = {}

local function AddAssets(folder)
	for _, inst in pairs(folder:GetDescendants()) do
		if inst:HasTag("Asset") then
			AssetsByID[inst.Name] = inst
		end
	end
end

if workspace:FindFirstChild("Assets") then
	workspace.Assets.Parent = ReplicatedStorage
end

AddAssets(ReplicatedStorage.Assets)

return function(assetName)
	assert(AssetsByID[assetName], "No asset with name: " .. tostring(assetName) .. " found")
	return AssetsByID[assetName]
end
