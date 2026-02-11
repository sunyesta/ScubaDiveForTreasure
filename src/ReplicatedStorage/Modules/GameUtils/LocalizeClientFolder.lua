local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaitUtils = require(ReplicatedStorage.NonWallyPackages.WaitUtils)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Streamable = require(ReplicatedStorage.Packages.Streamable)

return function(model)
	local trove = Trove.new()
	local clientStreamable = trove:Add(Streamable.new(model, "Client"))

    clientStreamable

    

	-- 1. STREAMING SAFETY: Ensure all data is present
	-- This part was perfect. Keep it.
	assert(model:GetAttribute("DescendantCount"), "Requires DescendantCount")
	WaitUtils.WaitForDescendantsCount(model, model:GetAttribute("DescendantCount")):expect()

	local clientFolder = model:WaitForChild("Client")

	-- 2. EFFICIENT CLONING
	-- Clone the root once. This preserves all properties, attributes, and hierarchy automatically.
	local newClient = clientFolder:Clone()

	-- 3. (Optional) BUILD THE MAP
	-- If you strictly need the [Original] -> [Clone] map for other logic:

	-- Get lists of descendants from both.
	-- Since the hierarchy is identical, the indexes will match.
	local originalDescendants = clientFolder:GetDescendants()
	local newDescendants = newClient:GetDescendants()

	for i, original in ipairs(originalDescendants) do
		local clone = newDescendants[i]

		-- If you need to manipulate the PrimaryPart:
		if original == model.PrimaryPart then
			model.PrimaryPart = clone
		end
	end

	-- 4. Finalize
	newClient.Parent = model
	clientFolder:Destroy()
end
