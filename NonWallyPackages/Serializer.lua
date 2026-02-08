local TypeSerializer = {}

function TypeSerializer.Serialize(val)
	if type(val) == "string" then
		return val
	elseif typeof(val) == "Vector3" then
		return { X = val.X, Y = val.Y, Z = val.Z }
	elseif typeof(val) == "Color3" then
		return val:ToHex()
	elseif typeof(val) == "CFrame" then
		return { val:GetComponents() }
	else
		print("unsupported type")
		error("Unsupported type " .. typeof(val))
	end
end

function TypeSerializer.Deserialize(valType, val)
	if valType == "string" then
		return val
	elseif valType == "Vector3" then
		return Vector3.new(val.X, val.Y, val.Z)
	elseif valType == "Color3" then
		return Color3.fromHex(val)
	elseif valType == "CFrame" then
		return CFrame.new(table.unpack(val))
	else
		error("Unsupported type " .. valType)
	end
end

return TypeSerializer
