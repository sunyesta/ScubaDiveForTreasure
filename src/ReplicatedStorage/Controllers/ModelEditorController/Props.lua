local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Input = require(ReplicatedStorage.Packages.Input)
local MouseTouch = require(ReplicatedStorage.NonWallyPackages.MouseTouch)
local Assert = require(ReplicatedStorage.NonWallyPackages.Assert)

-- The Props module holds all shared state and input singletons
-- This prevents circular dependencies between Tools and the Main Controller
local Props = {}

Props.Active = Property.new(false)
Props.State = Property.new()
Props.ActiveGizmo = Property.new()
Props.ShowGizmos = Property.new(false)
Props.SelectedModel = Property.new()
Props.FakeCursorPart = Property.new(nil)
Props.IsDiscarding = Property.new(false)
Props.LockCamera = Property.new(false)
Props.SelectedMaterial = Property.new()
Props.ConfigName = Property.new()

Props.Config = {}
Props.Instances = {}
Props.ActiveTrove = nil
Props.RunningStatePromise = nil

Props.Player = Players.LocalPlayer
Props.CurrentCamera = Workspace.CurrentCamera
Props.Mouse = Input.Mouse.new()
Props.MouseTouch = MouseTouch.new({
	Gui = false,
	Thumbstick = true,
	Unprocessed = true,
})
Props.MouseTouchGui = MouseTouch.new({
	Gui = true,
	Thumbstick = true,
	Unprocessed = true,
})

function Props.AssertStatePromiseNotRunning()
	Assert(
		Props.RunningStatePromise == nil or Props.RunningStatePromise:getStatus() ~= "Started",
		Props.State:Get(),
		" has not finished running",
		Props.RunningStatePromise,
		if Props.RunningStatePromise then Props.RunningStatePromise:getStatus() else nil
	)
end

return Props
