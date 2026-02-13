local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local StartLoadingScreen = require(ReplicatedStorage.Common.Components.GUIs.StartLoadingScreen)
local Player = Players.LocalPlayer

-- create and start the loading screen
ReplicatedFirst:RemoveDefaultLoadingScreen()
local startLoadingScreen = ReplicatedFirst:WaitForChild("StartLoadingScreen"):Clone()
startLoadingScreen.Parent = Player.PlayerGui
StartLoadingScreen:WaitForInstance(startLoadingScreen):expect()
StartLoadingScreen.Open()

-- wait for the player to load on the server
StartLoadingScreen.UpdateStatus("Waiting for player to load on server...")
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()
local PlayerLoaded = Property.BindToCommProperty(PlayerComm.PlayerLoaded)
PlayerLoaded:WaitForTrue():expect()

local function loadDescendants(path, callback)
	for _, file in path:GetDescendants() do
		if file:IsA("ModuleScript") then
			StartLoadingScreen.UpdateStatus("Loading " .. file.Name .. "...")
			local loadedFile = require(file)
			if callback then
				callback(loadedFile)
			end
		end
	end
end

-- load all the client modules
loadDescendants(ReplicatedStorage.Common.Controllers)
loadDescendants(ReplicatedStorage.Common.Components, function(comp)
	if comp.Singleton then
		StartLoadingScreen.UpdateStatus("Waiting for instance for " .. comp.Tag .. "...")
		local allComp = comp:GetAll()
		while #allComp == 0 do
			task.wait(0.01)
			allComp = comp:GetAll()
		end
	end
end)

-- Start the controllers
StartLoadingScreen.UpdateStatus("Starting Game...")
for _, file in ReplicatedStorage.Common.Controllers:GetChildren() do
	if file:IsA("ModuleScript") then
		print(file.Name)
		local controller = require(file)
		if controller.GameStart then
			controller.GameStart()
		end
	end
end

StartLoadingScreen.UpdateStatus("Ready!")
task.wait(0.5)

StartLoadingScreen.Close()
