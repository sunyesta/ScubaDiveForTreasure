local CompReg = {}

CompReg._components = {}

function CompReg.Register(comp)
	CompReg._components[comp.Tag] = comp
end

function CompReg.Get(compTag)
	assert(CompReg._components[compTag], "Component " .. compTag .. " not found")
	return CompReg._components[compTag]
end

return CompReg
