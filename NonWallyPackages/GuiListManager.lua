--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Assuming these are the paths to your packages
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

-- 📝 7. Strict Typing for Trove
-- We define the methods of Trove that we actually use to get Luau autocomplete and strict checks.
export type Trove = {
	Add: (self: Trove, object: any, cleanupMethod: string?) -> any,
	Remove: (self: Trove, object: any) -> boolean,
	Clean: (self: Trove) -> (),
	Construct: (self: Trove, class: any, ...any) -> any,
	Connect: (self: Trove, signal: any, fn: (...any) -> ()) -> RBXScriptConnection,
}

-- 📝 3. Separation of Concerns
-- Split the callback into a Create and an Update phase.
type CreateGuiCallback = () -> GuiObject
type UpdateGuiCallback = (gui: GuiObject, key: any) -> ()

export type GuiListManager = typeof(setmetatable(
	{} :: {
		_Trove: Trove,
		_Adornee: GuiObject,

		_ActiveGuis: { [any]: GuiObject },
		_CachedGuis: { GuiObject },
		_LastKeyList: { any }?,

		_CreateGui: CreateGuiCallback,
		_UpdateGui: UpdateGuiCallback,

		-- 📝 5. Lifecycle Signals
		ItemAdded: RBXScriptSignal,
		ItemRemoved: RBXScriptSignal,

		_AddedBindable: BindableEvent,
		_RemovedBindable: BindableEvent,
	},
	{} :: any
))

local GuiListManager = {}
GuiListManager.__index = GuiListManager

--- Creates a new GuiListManager
function GuiListManager.new(
	adornee: GuiObject,
	createGui: CreateGuiCallback,
	updateGui: UpdateGuiCallback
): GuiListManager
	local self = setmetatable({}, GuiListManager)

	self._Trove = Trove.new()

	self._Adornee = adornee
	self._ActiveGuis = {} -- [key] = gui
	self._CachedGuis = {} -- Array of inactive Guis
	self._LastKeyList = nil

	self._CreateGui = createGui
	self._UpdateGui = updateGui

	-- Setup Lifecycle Signals
	self._AddedBindable = self._Trove:Add(Instance.new("BindableEvent"))
	self._RemovedBindable = self._Trove:Add(Instance.new("BindableEvent"))
	self.ItemAdded = self._AddedBindable.Event
	self.ItemRemoved = self._RemovedBindable.Event

	return self :: GuiListManager
end

--- Cleans up the entire manager
function GuiListManager:Destroy()
	self._Trove:Clean()
	self._ActiveGuis = {}
	self._CachedGuis = {}
end

--- 🚀 Helper: Checks if the new list is identical to the old one
function GuiListManager:_IsSameList(newList: { any }): boolean
	if not self._LastKeyList then
		return false
	end
	if #self._LastKeyList ~= #newList then
		return false
	end

	for i, key in ipairs(newList) do
		if self._LastKeyList[i] ~= key then
			return false
		end
	end

	return true
end

--- 🚀 Helper: Retrieves a GUI from the cache, or creates a new one
function GuiListManager:_GetFromCacheOrCreate(): GuiObject
	local cachedGui = table.remove(self._CachedGuis)

	if cachedGui then
		cachedGui.Visible = true
		return cachedGui
	end

	-- If cache is empty, create a new one
	local newGui = self._CreateGui()
	newGui.Parent = self._Adornee
	newGui.Visible = true

	-- Have the main Trove manage this GUI so we don't leak memory when destroyed
	self._Trove:Add(newGui)

	return newGui
end

--- Updates the UI list, creating new GUIs for new keys and hiding old ones
function GuiListManager:Update(keyList: { any })
	-- 📝 6. The "Dirty" Optimization
	-- If the list hasn't changed order or content, skip the update entirely!
	if self:_IsSameList(keyList) then
		return
	end

	-- Clone to track next time
	self._LastKeyList = table.clone(keyList)

	local seenKeys = {}

	-- 📝 1. The "Triple-Loop" Problem (Solved)
	-- Pass 1: Addition, Update, and Layout order in ONE single loop.
	for index, key in ipairs(keyList) do
		seenKeys[key] = true

		local gui = self._ActiveGuis[key]

		if not gui then
			-- 📝 2 & 4. Trove Overhead & Visibility vs Parenting
			-- We fetch from cache instead of Instantiating + creating sub-troves
			gui = self:_GetFromCacheOrCreate()
			self._ActiveGuis[key] = gui
			self._AddedBindable:Fire(key, gui)
		end

		-- Update layout order
		gui.LayoutOrder = index

		-- Update the data inside the GUI
		self._UpdateGui(gui, key)
	end

	-- Pass 2: Removal (Send to cache)
	for key, gui in pairs(self._ActiveGuis) do
		if not seenKeys[key] then
			-- Hide it and add it to the cache pool
			gui.Visible = false
			table.insert(self._CachedGuis, gui)

			-- Unmap from active dictionary
			self._ActiveGuis[key] = nil
			self._RemovedBindable:Fire(key, gui)
		end
	end
end

--- 📝 8. Cache Pruning
--- Call this occasionally (e.g., when a round ends) to clear out excess cached GUIs and save memory
function GuiListManager:PruneCache(maxSize: number)
	-- Default to 0 if no maxSize is provided
	maxSize = maxSize or 0

	while #self._CachedGuis > maxSize do
		local gui = table.remove(self._CachedGuis)
		if gui then
			-- Using Trove:Remove actually calls :Destroy() on the instance and removes it from memory!
			self._Trove:Remove(gui)
		end
	end
end

--- Returns a shallow copy of the active GUIs dictionary
function GuiListManager:GetGuisByKey(): { [any]: GuiObject }
	return TableUtil.Copy(self._ActiveGuis)
end

return GuiListManager
