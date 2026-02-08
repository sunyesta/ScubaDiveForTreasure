local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local TableUtil2 = {}

-- val1IsBetter(value1, value2, key1, key2) - return true if value1 is better than value2
-- first val is returned if no vals are better than it
function TableUtil2.Best(list, val1IsBetter)
	local bestKey, bestVal = next(list)

	local listSize = 0
	for key1, val1 in pairs(list) do
		listSize += 1
		if val1IsBetter(val1, bestVal, key1, bestKey) then
			bestKey = key1
			bestVal = val1
		end
	end

	if listSize == 0 then
		return nil
	end

	return list[bestKey], bestKey
end

-- WARNING: does not preserve order!
function TableUtil2.RemoveDupes(list)
	local dict = {}
	for _, val in pairs(list) do
		dict[val] = true
	end

	return dict.keys()
end

function TableUtil2.ToDict(list)
	local newList = {}

	for _, item in pairs(list) do
		newList[item] = true
	end
	return newList
end

function TableUtil2.SetLength(list, defaultVal, n)
	if #list > n then
		return TableUtil.Truncate(list, n)
	else
		return TableUtil.Extend(list, table.create(n - #list, defaultVal))
	end
end

function TableUtil2.RemoveNils(list)
	local newList = {}
	for _, x in pairs(list) do
		table.insert(newList, x)
	end
	return newList
end

function TableUtil2.InsertSorted(list, value, isFirstBetter)
	local newList = {}
	local inserted = nil

	for _, x in pairs(list) do
		if inserted == nil and isFirstBetter(value, x) then
			table.insert(newList, value)
			inserted = #newList
		end
		table.insert(newList, x)
	end

	if inserted == nil then
		table.insert(newList, value)
		inserted = #newList
	end

	return newList, inserted
end

function TableUtil2.FindSimple(list, value)
	local _, i = TableUtil.Find(list, function(value2)
		return value == value2
	end)

	return i
end

function TableUtil2.CreateCounter(list)
	local counter = {}
	for _, val in list do
		if not counter[val] then
			counter[val] = 0
		end
		counter[val] += 1
	end

	return counter
end

function TableUtil2.Max(list)
	return math.max(unpack(list))
end

function TableUtil2.InsertAndSlideTheRestDown(list, index, value)
	local newList = TableUtil.Copy(list)

	local length = TableUtil2.Max(TableUtil.Keys(list))

	-- 1. Check if the index is valid
	if index < 1 then
		warn("TableUtil2.InsertAndSlideTheRestDown: Index out of bounds.")
		return -- Exit the function
	end

	-- 2. Shift all elements from the end down to the target index
	-- The loop goes from the current last index down to the target index.
	-- We use #newList + 1 as the starting point for the *new* last element (where we'll move the old last element).
	for i = length, index, -1 do
		newList[i + 1] = newList[i]
	end

	-- 3. Insert the new value at the target index
	newList[index] = value

	return newList
end

return TableUtil2
