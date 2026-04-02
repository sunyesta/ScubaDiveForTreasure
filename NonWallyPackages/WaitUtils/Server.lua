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

function WaitUtils.Loop(secs: number, callback: (stop: () -> ()) -> ()): () -> ()
	local isStopped = false

	-- Define the function that stops the loop
	local function stopFunc()
		isStopped = true
	end

	-- Use task.spawn to run the loop in a separate thread without yielding the main script
	task.spawn(function()
		while not isStopped do
			-- Execute the callback and pass the stop function to it
			callback(stopFunc)

			-- Wait the specified duration
			task.wait(secs)

			-- If the callback called stopFunc(), we should exit immediately
			-- instead of running the callback one more time.
			if isStopped then
				break
			end
		end
	end)

	-- Return the stop function so the script that started the loop can stop it externally
	return stopFunc
end
return WaitUtils
