local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local WaitUtilsComm

local WaitUtils = {}

function WaitUtils.DescendantsLoaded(inst: Instance)
	assert(inst ~= nil, "inst must exist")

	return Promise.new(function(resolve, reject)
		WaitUtilsComm = WaitUtilsComm or ClientComm.new(ReplicatedStorage.Comm, true, "WaitUtils"):BuildObject()

		local success, serverDescendants = WaitUtilsComm.GetInstanceData(nil, inst):await()
		if not success then
			reject(serverDescendants)
		end

		local descendants = #(inst:GetDescendants())

		if descendants >= serverDescendants then
			resolve()
		else
			local trove = Trove.new()
			trove:Add(inst.DescendantAdded:Connect(function()
				descendants = #(inst:GetDescendants())
				if descendants >= serverDescendants then
					resolve()
					trove:Clean()
				end
			end))
		end
	end)
end

function WaitUtils.WaitForDescendantsCount(inst: Instance, count)
	assert(count, "Count is nil")
	return Promise.new(function(resolve)
		local descendantsCount = #inst:GetDescendants()
		if descendantsCount >= count then
			resolve()
			return
		end

		local trove = Trove.new()
		local troveCleaned = false

		trove:Add(function()
			troveCleaned = true
		end)

		trove:Add(inst.DescendantAdded:Connect(function()
			descendantsCount += 1
			if descendantsCount == count then
				resolve()
				trove:Clean()
			end
		end))

		trove:Add(inst.DescendantRemoving:Connect(function()
			descendantsCount -= 1
			if descendantsCount == count then
				resolve()
				trove:Clean()
			end
		end))

		task.delay(5, function()
			if not troveCleaned then
				warn(
					inst,
					" has possible infinit wait for waiting on "
						.. tostring(count)
						.. " descendants"
						.. ". It currently has "
						.. tostring(#inst:GetDescendants())
				)
			end
		end)
	end)
end

function WaitUtils.WaitForChildren(parent, childrenNames)
	return Promise.new(function(resolve, reject)
		if #childrenNames == 0 then
			resolve()
		end

		local loaded = 0
		for _, childName in pairs(childrenNames) do
			task.spawn(function()
				parent:WaitForChild(childName)
				loaded += 1

				if loaded >= #childrenNames then
					resolve()
				end
			end)
		end
	end)
end

function WaitUtils.WaitForChildFromPath(root, path)
	root = root or game
	path = path:split("/")

	return Promise.new(function(resolve)
		for _, instName in pairs(path) do
			root = root:WaitForChild(instName)
		end

		resolve(root)
	end)
end

task.spawn(function()
	local InstanceLoaded = script.Parent:WaitForChild("InstanceLoaded")
	local InstanceListLoaded = script.Parent:WaitForChild("InstanceListLoaded")

	InstanceLoaded.OnClientInvoke = function(instance)
		if instance then
			return true
		else
			return false
		end
	end

	InstanceListLoaded.OnClientInvoke = function(instances)
		for _, inst in ipairs(instances) do
			if inst == nil then
				return false
			end
		end

		return true
	end
end)

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
