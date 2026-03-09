local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm

local TeleporterServer = Component.new({
	Tag = "Teleporter",
	Ancestors = { Workspace },
})

-- Helper function to assert that the instance is governed by Persistent streaming
local function assertPersistentStreaming(instance: Instance)
	-- Find the first ancestor that is a Model, or use the instance itself if it is a Model
	local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorWhichIsA("Model")

	-- Assert will throw an error in the console if the condition is false
	assert(
		model and model.ModelStreamingMode == Enum.ModelStreamingMode.Persistent,
		string.format(
			"[TeleporterServer] ERROR: '%s' must be placed inside a Model with ModelStreamingMode set to 'Persistent'!",
			instance:GetFullName()
		)
	)
end

function TeleporterServer:Construct()
	self._Trove = Trove.new()
	self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm"))
end

function TeleporterServer:Start()
	-- 1. Assert all teleporters that already exist in the Workspace
	for _, teleporter in CollectionService:GetTagged("Teleporter") do
		assertPersistentStreaming(teleporter)
	end

	-- 2. Assert all exit parts that already exist in the Workspace
	for _, exitPart in CollectionService:GetTagged("TeleporterExit") do
		assertPersistentStreaming(exitPart)
	end

	-- 3. (Optional but recommended) Listen for any new teleporters spawned during runtime
	self._Trove:Connect(CollectionService:GetInstanceAddedSignal("Teleporter"), assertPersistentStreaming)
	self._Trove:Connect(CollectionService:GetInstanceAddedSignal("TeleporterExit"), assertPersistentStreaming)
end

function TeleporterServer:Stop()
	self._Trove:Clean()
end

return TeleporterServer
