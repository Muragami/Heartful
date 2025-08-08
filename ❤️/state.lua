-- initialize a new default state with one or more arguments
return function(name, stype, mapfile)
	stype = tostring(stype)
	if not (stype == 'mapped' or stype == 'functional') then
		error('unkown state type `' .. stype .. '` passed to state initializer')
	end
	return {
		type = 'code',    -- we are code!
		subtype = 'state', -- we are a state!
		style = stype,    -- is this is 'functional', we call :enter() and :exit(),
		-- or set to 'mapped' and leave this file empty, and provide a map entry
		map = mapfile or false, -- set this to a string in order to resolve the map lua file											
		running = true,   -- we are running, if this is ever set to false the system will exit() it
		lifetime = false, -- if a number, the amount of seconds until running is set to false and we exit()
		name = name or false, -- name of this state, only one state of a given name can exist at once (false/nil for a nameless state)
		classname = 'state',
		classid = -1,
	}
end
