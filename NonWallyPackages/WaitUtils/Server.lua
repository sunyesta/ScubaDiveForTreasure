local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Promise = require(ReplicatedStorage.Packages.Promise)
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitUtilsComm = ServerComm.new(ReplicatedStorage.Comm, "WaitUtils")

local InstanceLoaded = Instance.new("RemoteFunction")
InstanceLoaded.Name = "InstanceLoaded"
InstanceLoaded.Parent = script.Parent

local InstanceListLoaded = Instance.new("RemoteFunction")
InstanceListLoaded.Name = "InstanceListLoaded"
InstanceListLoaded.Parent = script.Parent

WaitUtilsComm:BindFunction("GetInstanceData", function(player, instance)
	return #(instance:GetDescendants())
end)

WaitUtilsComm:BindFunction("IsLoaded", function() end)

local WaitUtils = {}

function WaitUtils.InstanceLoaded(player, instance)
	return Promise.new(function(resolve, reject)
		local counter = 0
		while true do
			local success, exists = pcall(function()
				return InstanceLoaded:InvokeClient(player, instance)
			end)
			if not success then
				reject(exists)
				return
			end

			if exists then
				resolve()
				return
			else
				task.wait(1)
				counter += 1
				if counter == 3 then
					warn(instance, "is not loading for", player)
				end
			end
		end
	end)
end

function WaitUtils.InstanceListLoaded(player, instances)
	return Promise.new(function(resolve, reject)
		instances = TableUtil2.RemoveNils(instances)

		local counter = 0
		while true do
			local success, exists = pcall(function()
				return InstanceListLoaded:InvokeClient(player, instances)
			end)
			if not success then
				reject(exists)
				return
			end

			if exists then
				resolve()
				return
			else
				task.wait(1)
				counter += 1
				if counter > 3 then
					warn(instances, "are not loading for", player)
					return
				end
			end
		end
	end)
end

function WaitUtils.BindToWait(secs, callback)
	local stop = false

	local stopFunc = function()
		stop = true
	end

	task.spawn(function()
		while task.wait(secs) do
			if stop then
				break
			end
			callback(stopFunc)
		end
	end)

	return stopFunc
end

return WaitUtils
