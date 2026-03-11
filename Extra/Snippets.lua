-- Player Comm

local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()

local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
self._Comm = self._Trove:Add(ServerComm.new(self.Instance, "_Comm"))
