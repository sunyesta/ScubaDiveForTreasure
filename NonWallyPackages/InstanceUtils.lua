local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DefaultValue = require(ReplicatedStorage.NonWallyPackages.DefaultValue)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Assert = require(ReplicatedStorage.NonWallyPackages.Assert)
local InstanceUtils = {}

-- includeSelf defaults to true
function InstanceUtils.FindAncestor(instance, callback, includeSelf)
	includeSelf = DefaultValue(includeSelf, true)

	local ancestor = instance
	if ancestor == nil then
		return nil
	end

	if not includeSelf then
		ancestor = ancestor.Parent
	end

	while true do
		if not ancestor then
			break
		end

		if callback(ancestor) then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

-- includeSelf defaults to true
function InstanceUtils.FindFirstAncestorWithTag(instance, tag, includeSelf)
	return InstanceUtils.FindAncestor(instance, function(ancestor)
		return ancestor:HasTag(tag)
	end, includeSelf)
end

function InstanceUtils.InGame(instance)
	local ancestor = instance

	while true do
		if not ancestor.Parent then
			break
		end

		ancestor = ancestor.Parent
	end

	-- print(ancestor)
	return ancestor == game
end

function InstanceUtils.HasAncestor(instance, ancestor)
	return ancestor:IsAncestorOf(instance)
end

function InstanceUtils.FindFirstChild(instance, recursive, callback, includeSelf)
	if includeSelf and callback(instance) then
		return instance
	end

	for _, child in pairs(instance:GetChildren()) do
		if callback(child) then
			return child
		end
	end

	if recursive then
		for _, child in pairs(instance:GetChildren()) do
			local result = InstanceUtils.FindFirstChild(child, true, callback, true)
			if result then
				return result
			end
		end
	end
end

function InstanceUtils.GetPath(root, inst)
	local curInst = inst
	local path = {}

	while curInst and (curInst ~= root) do
		table.insert(path, curInst.Name)

		curInst = curInst.Parent
	end

	Assert(curInst == root, "no path found from", root, "to", inst)

	path = TableUtil.Reverse(path)

	local pathString = ""

	for _, pathInst in pairs(path) do
		Assert(not string.find(tostring(pathInst), "/"), "/ characters are not allowed in instance names", pathInst)

		pathString = pathString .. tostring(pathInst) .. "/"
	end
	pathString = pathString:sub(0, -2)

	return pathString
end

function InstanceUtils.GetInstFromPath(root, path)
	path = path:split("/")

	local curInst = root
	for _, instName in pairs(path) do
		curInst = curInst[instName]
		if not curInst then
			error("no inst found for path " .. TableUtil.EncodeJSON(path))
			return nil
		end
	end

	return curInst
end

function InstanceUtils.GetSelfAndDescendants(inst)
	return TableUtil.Extend(inst:GetDescendants(), { inst })
end

local counter = 0
function InstanceUtils.GenerateUniqueInGameID()
	local name = "simpleID" .. counter
	counter += 1
	return name
end

function InstanceUtils.RemoveParent(inst)
	inst.Parent = nil
	return inst
end

function InstanceUtils.ObserveTaggedDescendants(inst, tag, callback)
	for _, desc in pairs(inst:GetDescendants()) do
		if desc:HasTag(tag) then
			callback(desc)
		end
	end

	return inst.DescendantAdded:Connect(function(desc)
		if desc:HasTag(tag) then
			callback(desc)
		end
	end)
end

function InstanceUtils.GetTaggedDescendants(inst, tag)
	local insts = {}
	for _, desc in pairs(inst:GetDescendants()) do
		if desc:HasTag(tag) then
			table.insert(insts, desc)
		end
	end

	return insts
end

return InstanceUtils
