local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Singleton = {}
Singleton.__index = Singleton

Singleton.CURRENTLY_REPLACING_ERR_MESSAGE = "Currently Replacing"

function Singleton.new(usePromise)
	local self = setmetatable({}, Singleton)

	self._Trove = Trove.new()
	self._UsePromise = usePromise
	self._CurrentlyReplacing = false

	return self
end

function Singleton:Destroy()
	self._Trove:Clean()
end

function Singleton:Replace(createFunc)
	local function doReplace()
		self._CurrentlyReplacing = true

		self._Trove:Clean()
		local cleanup = createFunc()
		assert(cleanup, "no cleanup function found")
		self._Trove:Add(cleanup)

		self._CurrentlyReplacing = false
	end

	if self._UsePromise then
		-- This ensures the lock is always released, even if an error occurs.
		return Promise.new(function(resolve, reject)
			if self._CurrentlyReplacing then
				reject(Singleton.CURRENTLY_REPLACING_ERR_MESSAGE)
				return
			end

			doReplace()

			resolve()
		end)
	else
		assert(not self._CurrentlyReplacing, "Singleton is currently being replaced" .. tostring(self._UsePromise))
		doReplace()
	end
end

return Singleton
