local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)
local GetAssetByName = require(ReplicatedStorage.Common.Modules.GetAssetByName)

Loader.LoadDescendants(ServerStorage.Source.Services)
Loader.LoadDescendants(ServerStorage.Source.Components)

-- Start the services
for _, file in ServerStorage.Source.Services:GetDescendants() do
	if file:IsA("ModuleScript") then
		local service = require(file)
		if service.GameStart then
			service.GameStart()
		end
	end
end

print("Server Fully loaded")
