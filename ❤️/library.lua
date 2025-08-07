-- initialize a new default state with one or more arguments
return function(name, stype, mapfile)
	name = tostring(name)
	stype = tostring(stype)
	if not (stype == 'mapped' or stype == 'functional') then
		error('unkown state type `' .. stype .. '` passed to state initializer')
	end
	return {
		type = 'code',						-- we are code!
		subtype = 'library',			-- we are a state!
		style = stype,						-- is this is 'functional', we call :enter() and :exit(), 
															-- or set to 'mapped' and leave this file empty, and provide a map entry
		map = mapfile or false,		-- set this to a string in order to resolve the map lua file											
		name = name,							-- name of this state, only one state of a given name can exist at once (false/nil for a nameless state)
		classname = 'library',
		classid = -1,
	}
end