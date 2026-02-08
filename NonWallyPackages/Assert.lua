return function(bool, ...)
	if not bool then
		print(...)
		error("view above print")
	end
end
