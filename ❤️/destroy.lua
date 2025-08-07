--[[
	Here we handle object destruction in the Heartful engine
]]

local xhen = false

-- a routine to handle the destruction of the children of an entity
local function destroyChildren(obj)
	for _, v in ipairs(obj.children) do
		if v.classname then
			xhen.doClassLogic('destroychild', v, obj)
		end
		v:destroy(hen)
	end
end

-- deconstructor code for all the things
return {
	_setxhen = function(hen)
		xhen = hen
	end,
	drawable = function(obj)
		destroyChildren(obj)
	end,
	entity = function(obj)
		destroyChildren(obj) 
	end,
	nonentity = function(obj)
		destroyChildren(obj) 
	end,
	shadow = function(obj)
		destroyChildren(obj) 
	end,
	duplicate = function(obj)
		destroyChildren(obj) 
	end,
	screen = function(obj)
		xhen:remove('_draw', obj)
		xhen:remove('_update', obj)
		destroyChildren(obj)
	end,
	layer = function(obj)
		destroyChildren(obj)
	end,
	rasterlayer = function(obj) 
		destroyChildren(obj)
	end,
	basiclayer = function(obj) 
		destroyChildren(obj)
	end,
	userlayer = function(obj) 
		destroyChildren(obj)
	end,
	shape = function(obj) 
		destroyChildren(obj)
	end,
	shapes = function(obj)
		destroyChildren(obj) 
	end,
	image = function(obj) 
		destroyChildren(obj)
	end,
	sprite = function(obj)
		destroyChildren(obj) 
	end,
	bitmap = function(obj) 
		destroyChildren(obj)
	end,
	font = function(obj) 
		destroyChildren(obj)
	end,
	shader = function(obj)
		destroyChildren(obj) 
	end,
	config = function(obj) 
		destroyChildren(obj)
	end,
	sample = function(obj)
		destroyChildren(obj) 
	end,
	stream = function(obj) 
		destroyChildren(obj)
	end,
}