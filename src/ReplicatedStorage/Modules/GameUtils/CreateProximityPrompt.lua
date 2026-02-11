return function(instance, message)
	-- creates a proximity prompt with the letter E
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = message -- The text displayed to the player (e.g., "Open")
	prompt.KeyboardKeyCode = Enum.KeyCode.E -- Sets the interaction key to E
	prompt.Parent = instance -- Parents the prompt to the specified part
	prompt.RequiresLineOfSight = false
	prompt:AddTag("ProximityPrompt")
	prompt:SetAttribute("ProxEnabled", true)
	return prompt
end
