--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Trove = require(ReplicatedStorage.Packages.Trove)
local BehaviorTreeCreator = require(script.BehaviorTreeCreator)

-- ============================================================================
-- BEHAVIOR TREE CREATOR OVERRIDE
-- Completely ignores physical ModuleScripts for Task nodes. Instead, it routes
-- execution dynamically through the task objects inside `taskTable`.
-- ============================================================================
BehaviorTreeCreator._getSourceTask = function(_self, folder)
	local taskName = folder.Name

	-- Return a dynamic proxy task that the Behavior Tree Runner will execute.
	-- This bridges the internal BT5 runner to our custom Task objects.
	return {
		start = function(entity, ...)
			local taskObj = entity.Tasks and entity.Tasks[taskName]
			if taskObj and type(taskObj.Start) == "function" then
				taskObj.Start(...) -- entity omitted
			end
		end,

		run = function(entity, ...)
			local taskObj = entity.Tasks and entity.Tasks[taskName]
			if taskObj and type(taskObj.Run) == "function" then
				local status = taskObj.Run(...) -- entity omitted

				-- Safety check: ensure the function returned a valid status enum
				if status == nil then
					warn(
						string.format(
							"[MyBehaviorTree] Task '%s' returned nil! You must return a Status (1, 2, or 3). Defaulting to FAIL.",
							taskName
						)
					)
					return 2 -- FAIL
				end

				return status
			end

			warn(
				string.format(
					"[MyBehaviorTree] Tree attempted to run Task '%s', but it was not provided or lacks a 'Run' method!",
					taskName
				)
			)
			return 2 -- FAIL
		end,

		finish = function(entity, status, ...)
			local taskObj = entity.Tasks and entity.Tasks[taskName]
			if taskObj and type(taskObj.Finish) == "function" then
				taskObj.Finish(status, ...) -- entity omitted
			end
		end,
	}
end
-- ============================================================================

local Task = {}

Task.Status = {
	SUCCESS = 1,
	FAIL = 2,
	RUNNING = 3,
}

-- Factory for creating a base Task object
function Task.new()
	return {
		Start = function(...) end,
		Finish = function(status, ...) end,
		Run = function(...)
			return Task.Status.SUCCESS
		end,
	}
end

local MyBehaviorTree = {}
MyBehaviorTree.__index = MyBehaviorTree

MyBehaviorTree.Task = Task

-- Define our strictly typed TaskObject and TaskTable without the entity parameter
export type TaskObject = {
	Start: ((...any) -> ())?,
	Run: (...any) -> number,
	Finish: ((status: number, ...any) -> ())?,
}

export type TaskTable = { [string]: TaskObject }

--[[
    Initializes a new Behavior Tree wrapper.
    @param treeFolder The folder containing the compiled Behavior Tree.
    @param taskTable A dictionary mapping task names to Task objects.
]]
function MyBehaviorTree.Start(treeFolder: Folder, taskTable: TaskTable)
	local self = setmetatable({}, MyBehaviorTree)
	self._Trove = Trove.new()

	-- 1. Create or retrieve the parsed tree from the Creator
	-- Because of our override above, this will no longer error if physical ModuleScripts are missing!
	self.Tree = BehaviorTreeCreator:Create(treeFolder)

	-- 2. Construct the "Entity" object.
	-- The dynamic proxy task we created above reads from `entity.Tasks`
	self.Entity = {
		Tasks = taskTable,
		Blackboard = {}, -- Standard BT5 blackboard for state memory
	}

	-- Ensure the tree aborts safely if this wrapper is destroyed
	self._Trove:Add(function()
		if self.Tree then
			self:Abort()
		end
		self.Entity = nil :: any
	end)

	return self
end

--[[
    Steps the behavior tree forward. Should be called on an interval or heartbeat.
]]
function MyBehaviorTree:Step(...)
	if self.Tree and self.Entity then
		return self.Tree:Run(self.Entity, ...)
	end
	return nil
end

--[[
    Aborts the currently running task in the tree.
    Useful for interrupting the monster if it gets stunned or dies.
]]
function MyBehaviorTree:Abort(...)
	if self.Tree and self.Entity then
		self.Tree:Abort(self.Entity, ...)
	end
end

--[[
    Cleans up the wrapper.
]]
function MyBehaviorTree:Destroy()
	self._Trove:Clean()
end

return MyBehaviorTree
