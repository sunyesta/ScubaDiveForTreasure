local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Singleton = require(ReplicatedStorage.NonWallyPackages.Singleton)

-- Controller
local MainGuiController = {}

-- Initialize storage immediately to allow registration before Start runs
MainGuiController.Registered = {}

function MainGuiController.ReplaceGui(name, openGuiFunc)
	if not MainGuiController._Singleton then
		warn("MainGuiController is not started yet.")
		return Promise.reject("MainGuiController not started")
	end

	return MainGuiController._Singleton:Replace(openGuiFunc):andThen(function()
		MainGuiController._ActiveGui:Set(name)
	end)
end

-- call using .ReplaceWithRegistered(registered name, props that go into the function you registered with)
function MainGuiController.ReplaceWithRegistered(name, ...)
	local args = { ... }
	assert(MainGuiController.Registered[name], tostring(name) .. " has not been registered")

	MainGuiController.ReplaceGui(name, function()
		return MainGuiController.Registered[name](table.unpack(args))
	end)
end

function MainGuiController.Register(name, openGuiFunc)
	MainGuiController.Registered[name] = openGuiFunc
end

function MainGuiController.GameStart()
	-- Private properties
	MainGuiController._Trove = Trove.new()
	MainGuiController._Singleton = Singleton.new(true, true)
	MainGuiController._ActiveGui = Property.new()

	-- Public properties
	MainGuiController.ActiveGui = Property.ReadOnly(MainGuiController._ActiveGui)

	-- MainGuiController.ReplaceWithRegistered("MainGui")
end

return MainGuiController
