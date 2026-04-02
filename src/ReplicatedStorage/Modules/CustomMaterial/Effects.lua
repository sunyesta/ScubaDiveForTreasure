-- TODO not in use!

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Property = require(ReplicatedStorage.NonWallyPackages.Property)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)


local Effects = {}
Effects.AttributeName = "EffectList"

function Effects._DeserializeEffectsList(effectsListSTR)
    return TableUtil.DecodeJSON(effectsListSTR)
end


function Effects._SerializeEffectsList(effectsList)
    return TableUtil.EncodeJSON(effectsList)
end


function Effects.GetEffectsList(basePart)
    local effectsListSTR = basePart:GetAttribute(Effects.AttributeName)
    if effectsListSTR then
           return Effects._DeserializeEffectsList(effectsListSTR)
    else
        return {}
    end
 
    
end

function Effects.AddEffect(basePart,effectName)
    local effectsList = Effects.GetEffectsList(basePart)

    if not table.find(effectsList, effectName) then
        table.insert(effectsList, effectName)
    end
    

    basePart:SetAttribute(Effects.AttributeName, Effects._SerializeEffectsList(effectsList))

end


function Effects.CreateProperty(basePart)
    local trove= Trove.new()

    local _effectsList = trove:Add(Property.new({}))
    local effectsList = Property.ReadOnly(_effectsList) --don't use trove add here bc it gets destroyed in effectsList.Destroy()

    local oldEffectsListSTR = nil
	trove:Add(basePart:GetAttributeChangedSignal(Effects.AttributeName):Connect(function()
		local effectsListSTR = basePart:GetAttribute(Effects.AttributeName)
		if effectsListSTR ~= oldEffectsListSTR then
			_effectsList:Set(Effects._DeserializeEffectsList(effectsListSTR))
		end
		oldEffectsListSTR = effectsListSTR
	end))



    effectsList.Destroy = function()
        Property.Destroy(effectsList)
        trove:Clean()
    end

    
    return effectsList
end


return Effects