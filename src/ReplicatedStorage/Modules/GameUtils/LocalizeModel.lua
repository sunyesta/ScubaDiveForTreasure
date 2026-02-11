local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaitUtils = require(ReplicatedStorage.NonWallyPackages.WaitUtils)
return function(model: Model)
	assert(
		model.ModelStreamingMode == Enum.ModelStreamingMode.Persistent,
		"Model streaming mode must be persistant for " .. tostring(model)
	)
	assert(model:GetAttribute("DescendantCount"), "DescendantCount attribute is required")
	WaitUtils.WaitForDescendantsCount(model, model:GetAttribute("DescendantCount"))

	-- 1. Store a reference to the original PrimaryPart (if it exists)
	local originalPrimaryPart = model.PrimaryPart

	-- 2. Iterate through every descendant of the model
	for _, descendant in ipairs(model:GetDescendants()) do
		-- We only want to swap physical parts (MeshParts, Parts, Unions, etc.)
		if descendant:IsA("BasePart") then
			-- Create a local clone of the part
			local localPart = descendant:Clone()

			-- Important: Prevents duplicating nested parts if your model has Parts inside Parts.
			-- We clear the clone's children because the loop will eventually handle
			-- the children as it iterates through them.
			localPart:ClearAllChildren()

			-- 3. Maintain the hierarchy
			-- We set the parent of the new part to the same parent as the old part
			localPart.Parent = descendant.Parent

			-- 4. Update the PrimaryPart
			-- If the part we just cloned was the model's PrimaryPart, update the Model to use the new local one.
			if descendant == originalPrimaryPart then
				model.PrimaryPart = localPart
			end

			-- 5. Delete the server version
			-- Since this runs on the client, Destroy() only removes it locally.
			-- This effectively "swaps" the server part for your new local part.
			descendant:Destroy()
		end
	end
end
