local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local GuiUtils = require(ReplicatedStorage.NonWallyPackages.GuiUtils)

local GuiListManager = {}
GuiListManager.__index = GuiListManager

function GuiListManager.new(adornee: GuiObject, buildGui)
	local self = setmetatable({}, GuiListManager)

	self._Trove = Trove.new()

	self._Adornee = adornee
	self._Guis = {} -- [key] = gui
	self._BuildGui = buildGui
	self._GuiTroves = {} -- [gui] = trove

	self.TweenInfo = TweenInfo.new(0.1)

	return self
end

function GuiListManager:Destroy()
	self._Trove:Clean()
end

-- creates new guis for new keys and deletes guis for removed keys
function GuiListManager:Update(keyList)
	local newKeys = TableUtil2.ToDict(keyList)

	-- Identify removed keys and destroy their GUIs
	for key, gui in pairs(self._Guis) do
		if not newKeys[key] then
			local guiTrove = self._GuiTroves[gui]
			if guiTrove then
				guiTrove:Clean()
			end
		end
	end

	-- Identify new keys and create new GUIs
	for _, key in keyList do
		if not self._Guis[key] then
			-- Key is new, create a GUI for it
			local guiTrove = self._Trove:Extend()
			local newGui = guiTrove:Add(self._BuildGui(key, guiTrove))

			-- Set up properties and parenting
			newGui.Parent = self._Adornee

			-- cleanup data
			self._Guis[key] = newGui
			self._GuiTroves[newGui] = guiTrove
			guiTrove:Add(function()
				self._Guis[key] = nil
				self._GuiTroves[newGui] = nil
			end)
		end
	end

	-- fix layout order of all guis
	for i, key in keyList do
		self._Guis[key].LayoutOrder = i
	end
end

function GuiListManager:GetGuisByKey()
	return TableUtil.Copy(self._Guis)
end

return GuiListManager
