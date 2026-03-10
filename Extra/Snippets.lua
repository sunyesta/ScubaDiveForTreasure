-- Player Comm (client)

local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local PlayerComm = ClientComm.new(ReplicatedStorage.Comm, true, "PlayerComm"):BuildObject()
