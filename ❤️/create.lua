--[[
	Here we build the functionality of objects in the Heartful engine
]]

-- ********************************************************************************
-- get utility functions
local util = require '❤️.util'
local subtable = util.subtable
local copyInto = util.copyInto
local makeCopy = util.makeCopy
local trimPath = util.trimPath
local dir2dot = util.dir2dot
local combine = util.combine
local split = util.split
local breakup = util.breakup
local remove = util.remove
local defaults = util.defaults
local buildSupers = util.buildSupers
local nocall = util.nocall
local null = util.null
local insertionSort = util.insertionSort
local mergeSort = util.mergeSort

-- local functions since they are called a lot
local tinsert = table.insert
local tremove = table.remove

-- love linkage
local lgnewquad = love.graphics.newQuad
local lgnewimage = love.graphics.newImage

-- neaded libs
local maxrects = require '❤️.maxrects'
local ffi = require 'ffi'

local xhen = null

-- construct a new maxrects packer class for a new raster layer
local function newPacker(width, height)	return maxrects.new(width, height, false) end

-- ********************************************************************************
-- base functionality

-- add a child to an object
local function addChild(obj, child)
	if child.parent then error('Cannot add child to multiple parents in obj: ' .. obj.name) end
	child.parent = obj
	tinsert(obj.children, child)
	child.parent_id = #obj.children
	if child.classname then
		xhen.doClassLogic('addchild', child, obj)
	end
end

-- remove a child from object
local function removeChild(obj, child)
	if not child.parent or not child.parent_id then error('Cannot remove child - missing? from obj: ' .. obj.name) end
	if child.classname then
		xhen.doClassLogic('removechild', child, obj)
	end
	if child.parent_id < #obj.children then
		-- move the last child into the open slot and remap it's id
		obj.children[child.parent_id] = obj.children[#obj.children]
		obj.children[child.parent_id].parent_id = child.parent_id
	end
	tremove(obj.children)
end

-- remove all children from object
local function removeChildren(obj)
	for _, v in ipairs(obj.children) do
		if v.classname then
			xhen.doClassLogic('removechild', v, obj)
		end
	end
	obj.children = {}
end

-- install base functions
local function installBase(obj)
	obj.addChild = addChild
	obj.removeChild = removeChild
	obj.removeChildern = removeChildren
end

-- ********************************************************************************
-- screen functionality

local function addLayer(obj, name, typeobj, cfg)
	local lobj
	if type(typeobj) == 'string' then
		lobj = xhen:create(name, typeobj, cfg)
	else
		lobj = typeobj
	end
	if not name then
		tinsert(obj.layer, lobj)
		lobj.layer_id = #obj.layer
	else
		obj.layer[name] = lobj
		lobj.layer_id = name
	end
	if lobj.classname then
		xhen:classify(lobj)
		xhen:doClassLogic('addlayer', obj, lobj)
	end
	obj.last_layer = lobj
	lobj.screen = obj
	return lobj
end

local function removeLayer(obj, nameobj)
	local lobj
	if type(nameobj) ~= 'table' then
		lobj = obj.layer[nameobj]
		if type(lobj) ~= 'table' then
			error('removeLayer() no such layer to remove: ' .. nameobj)
		end
	else
		lobj = nameobj
	end
	lobj.screen = false
	if type(lobj.layer_id) == 'number' then
		tremove(obj.layer, lobj.layer_id)
	else
		obj.layer[lobj.layer_id] = nil
	end
	if lobj.classname then
		xhen.doClassLogic('removelayer', obj, lobj)
	end
	if obj.own_shader then obj.own_shader[obj.layer_id] = nil end
end

-- this gets a little complicated because the screen owns
-- the shader of all layers without an explicitly assigned shader
local function setScreenShader(obj, shader)
	obj._shader = shader
	if not obj.own_shader then obj.own_shader = {} end
	local t = obj.own_shader
	for k, v in pairs(obj.layer) do
		if not v:getShader(xhen) then t[k] = v	end
	end
	for k, v in pairs(t) do
		v:setShader(shader, true) -- true so the layer knows it's a call from us
	end
end

local function getShader(obj)
	return obj._shader
end

local function screenClear(obj)
	local kill = xhen.kill
	obj.last_layer = false
	for _, v in pairs(obj.layer) do
		kill(xhen, v)
	end
	obj.layer = {}
end

-- sorting for layers
local function zless(a, b) return a.box.z < b.box.z end
local function yless(a, b) return a.box.y < b.box.y end
local function xless(a, b) return a.box.x < b.box.x end
local function zyless(a, b) 
	local ax = a.box
	local bx = b.box
	if ax.z == bx.z then
		return ax.y < bx.y
	else
		return ax.z < bx.z
	end
end
local function zyxless(a, b) 
	local ax = a.box
	local bx = b.box
	if ax.z == bx.z then
		if ax.y == bx.y then
			return ax.x < bx.x
		else
			return ax.y < bx.y
		end
	else
		return ax.z < bx.z
	end
end
local function yxless(a, b) 
	local ax = a.box
	local bx = b.box
	if ax.y == bx.y then
		return ax.x < bx.x
	else
		return ax.y < bx.y
	end
end

local function makeBuffer(obj, target)
	if type(obj._buffer) ~= 'table' then obj._buffer = {} end
	local t = obj._buffer
	local src = obj[target]
	for i = #t, #src, 1 do
		tinsert(t, null)
	end
end

-- TODO make the where options work
local function sort(obj, target, how, where) 
	makeBuffer(obj, target)
	mergeSort(obj[target], obj._buffer, how)
end

local sorts = {
	['zyx'] = {
		model = 'unoptimized',
		resolve = sort,
		lesseq = zyxless,
	},
	['zy'] = {
		model = 'unoptimized',
		resolve = sort,
		lesseq = zyless,
	},
	['yx'] = {
		model = 'unoptimized',
		resolve = sort,
		lesseq = yxless,
	},
	['z'] = {
		model = 'unoptimized',
		resolve = sort,
		lesseq = zless,
	},
	['y'] = {
		model = 'unoptimized',
		resolve = sort,
		lesseq = yless,
	},
	['x'] = {
		model = 'unoptimized',
		resolve = sort,
		lesseq = xless,
	},
}

local function setSort(obj, method)
	-- decode where options
	local function str2where(str)
		if str == '.middle' then return 50
		elseif str == '.bottom' or str == '.right' then return 100
		else
			return 0
		end
	end
	if not method then
		obj.sort = nil
		obj._buffer = nil
	end
	-- let's assign the sort system
	if method:sub(1, 3) == 'zyx' then
		obj.sort = sorts['zyx']
		obj.sort.where = str2where(method:sub(4))
	elseif method:sub(1, 2) == 'zy' then
		obj.sort = sorts['zy']
		obj.sort.where = str2where(method:sub(3))
	elseif method:sub(1, 2) == 'yx' then
		obj.sort = sorts['yx']
		obj.sort.where = str2where(method:sub(3))
	elseif method:sub(1, 1) == 'z' then
		obj.sort = sorts['z']
		obj.sort.where = str2where(method:sub(2))
	elseif method:sub(1, 1) == 'y' then
		obj.sort = sorts['y']
		obj.sort.where = str2where(method:sub(2))
	elseif method:sub(1, 1) == 'x' then
		obj.sort = sorts['x']
		obj.sort.where = str2where(method:sub(2))
	elseif method:sub(1, 1) == 'none' then
		obj.sort = nil
		obj._buffer = nil
	else
		error('setSort() unknown sort method: ' .. method)
	end
end

-- ********************************************************************************
-- layer functionality

local function setLayerShader(obj, shader, fromscreen)
	-- if we are owned by the screen, but are being explicitly set,
	-- make sure we remove us from that list anymore
	if not fromscreen and obj.screen.own_shader then obj.screen.own_shader[obj.layer_id] = nil end
	-- if we remove the shader from a layer, take the one from the screen
	if not fromscreen and not shader then
		obj._shader = obj.screen:getShader()
		if obj.screen.own_shader then obj.screen.own_shader[obj.layer_id] = obj end
	else
		obj._shader = shader
	end
end

local function addEntity(obj, thing)
	if thing.entity_id then error('addEntity() cannot add an entity to more than one layer, or more than once to a layer') end
	tinsert(obj.entity, thing)
	thing.entity_id = #obj.entity
end

local function removeEntity(obj, thing)
	if not thing.entity_id then error('removeEntity() cannot remove an entity not in a layer') end
	tremove(obj.entity, thing.entity_id)
	thing.entity_id = nil
end

local function layerClear(obj)
	local kill = xhen.kill
	for _, v in ipairs(obj.entity) do
		kill(xhen, v)
	end
	obj.entity = {}
end

local function setBuffered(obj)
	if obj.box.w > LoveLimit.texturesize or obj.box.h > LoveLimit.texturesize then
		error('setBuffered() cannot create a canvas ' .. obj.box.w .. 'x' .. obj.box.w .. ' exceeds maximum texture size')
	end
	obj.canvas = love.graphics.newCanvas(obj.box.w, obj.box.h)
end

local function isBuffered(obj)
	return obj.canvas ~= nil
end

-- install all layer functions
local function installLayer(obj)
	obj.getShader = getShader
	obj.setShader = setLayerShader
	obj.setSort = setSort
	obj.addEntity = addEntity
	obj.removeEntity = removeEntity
	obj.clear = layerClear
	obj.setBuffered = setBuffered
	obj.isBuffered = isBuffered
end

-- ********************************************************************************
-- rasterlayer functionality

local function changedRaster(layer)
	if layer.inherit then
		layer.inherit.rasterchange = true
	else
		layer.rasterchange = true
	end
end

local function addRaster(layer, thing)
	local list = layer.rasterlist
	if thing then 
		tinsert(list, { 0, 0, thing.box.w + (layer.rasterborder * 2), 
													thing.box.h + (layer.rasterborder * 2), thing, false } )
		thing.raster_id = #list
		changedRaster(layer) 	-- tell us to rebuild the raster map on update
	end
end

local function removeRaster(layer, thing)
	remove(layer.rasterlist, thing.raster_id)
	changedRaster(layer) 		-- tell us to rebuild the raster map on update
end

local function addRasterEntity(layer, thing)
	if thing.subtype ~= 'raster' then error('addEntity() cannot add a nonraster entity to a raster layer') end
	if thing.entity_id then error('addEntity() cannot add an entity to more than one layer, or more than once to a layer') end
	tinsert(layer.entity, thing)
	thing.entity_id = #layer.entity
	-- ok we added the thing, but do we have it's raster data
	-- in the raster map for this layer?
	thing.raster = layer.raster
	if not thing.imgdata then error('addEntity() a raster entity must have image data') end
	if not layer.rastermap[thing.imgdata] then 
		if layer.static or (layer.inherit and layer.inherit.static) then 
			error('addEntity() cannot add a new raster entity data to a static raster layer')
		end
		addRaster(layer, thing)
	end
end

local function removeRasterEntity(layer, thing)
	if not thing.entity_id then error('removeEntity() cannot remove an entity not in a layer') end
	tremove(layer.entity, thing.entity_id)
	thing.entity_id = nil
	-- we don't remove anything for a static raster layer, check that
	if layer.static or (layer.inherit and layer.inherit.static) then return end
	local rmap = layer.rastermap
	if rmap[thing.imgdata] then
		rmap[thing.imgdata] = rmap[thing.imgdata] - 1
		if rmap[thing.imgdata] == 0 then
			-- remove the raster listing for this entity
			removeRaster(layer, thing)
		end
	end
end

local function layerRasterClear(layer)
	local kill = xhen.kill
	local list = layer.rasterlist
	local rmap = layer.rastermap
	local rasterchange = false
	local rem
	if layer.static or (layer.inherit and layer.inherit.static) then 
		rem = nocall
	else
		rem = remove
	end
	for _, v in ipairs(layer.entity) do
		kill(xhen, v)
		rem(list, v.raster_id)
		if rem == remove and rmap[v.imgdata] then 
				-- reference counting for this raster data
			rmap[v.imgdata] = rmap[v.imgdata] - 1
			if rmap[v.imgdata] == 0 then
				rasterchange = true
			end
		end
	end
	if rem == remove and rasterchange then
		changedRaster(layer)
	end
	layer.entity = {}
end

local function rasterIsStatic(layer) return layer.static end
local function rasterSetStatic(layer, v) layer.static = v end
local function rasterInherit(to, from)
	if from.type ~= 'rasterlayer' then error('inherit() can only inherit from another raster layer') end
	to.inherit = from
	to._data = from.data
	to.raster = from.raster
	to.rasterbox = from.rasterbox
	to.rasterlist = from.rasterlist
	if #to.entity > 0 then -- add all our entities to the rasterlist we inherited
		local list = to.rasterlist
		local i = #list
	 	for _, v in ipairs(to.entity) do
	 		tinsert(list, { 0, 0, v.box.w, v.box.h, v, false } )
	 		i = i + 1
			v.raster_id = i
	 	end
	 	to.rasterchange = true 		-- tell us to rebuild the raster map on update
	end
end

-- install all rasterlayer functions
local function installRasterLayer(obj)
	obj.getShader = getShader
	obj.setShader = setLayerShader
	obj.setSort = setSort
	obj.addEntity = addRasterEntity
	obj.removeEntity = removeRasterEntity
	obj.clear = layerRasterClear
	obj.isStatic = rasterIsStatic
	obj.setStatic = rasterSetStatic
	obj.inherit = rasterInherit
end

-- ********************************************************************************
-- drawable functionality

local function color(obj, fg, bg)
	if type(fg) == 'table' then
		obj.fgcolor = fg[1] or obj.fgcolor
		obj.bgcolor = fg[2] or obj.bgcolor
		obj.palette = fg
	else
		obj.fgcolor = fg or obj.fgcolor
		obj.bgcolor = bg or obj.bgcolor
	end
end

local function visible(obj, yes)
	obj.visible = yes
end

local function style(obj, cfg)
	copyInto(cfg, obj.style)
end

local function localPalette(obj)
	obj.palette = makeCopy(obj.palette)
end

local function position(obj, x, y, z)
	local box = obj.box
	if type(x) == 'table' then
		box.x = x[1] or box.x
		box.y = x[2] or box.y
		box.z = x[3] or box.z
	else
		box.x = x or box.x
		box.y = y or box.y
		box.z = z or box.z
	end
end

local function scale(obj, sx, sy)
	obj.box.sx = sx or obj.box.sx
	obj.box.sy = sy or sx or obj.box.sy
end

local function rotate(obj, r, rox, roy)
	local box = obj.box
	box.r = r or box.r
	box.r = math.fmod(box.r, 360)
	if rox then
		box.rox = math.floor(rox * box.w * 0.01)
	else
		box.rox = math.floor(box.w * 0.5)
	end
	if roy then
		box.roy = math.floor(roy * box.h * 0.01)
	else
		box.roy = math.floor(box.h * 0.5)
	end
end

local function setDrawCfg(obj, cfg)
	local t
	if cfg.visible then visible(obj, cfg.visible) end
	if cfg.color then
		t = cfg.color
		if t.palette then
			color(obj, t.palette)
		else
			color(obj, t.fgcolor, t.bgcolor)
		end
	end
	if cfg.scale then
		t = cfg.scale
		if type(t) == 'number' then
			scale(obj, t)
		else
			scale(obj, t.x, t.y)
		end
	end
	if cfg.position then
		t = cfg.position
		position(obj, t.x, t.y, t.z)
	end
	if cfg.rotate then rotate(obj, cfg.rotate) end
	if cfg.rotation then
		t = cfg.rotation
		rotate(obj, t.r, t.x, t.y)
	end
	if cfg.style then copyInto(cfg.style, obj.style) end
	if obj._setCfg then
		for _, v in ipairs(obj._setCfg) do v(obj, cfg)	end
	end
end

local function getDrawCfg(obj, t)
	local box = obj.box
	if not t then t = {} end
	t.visible = obj.visible
	if obj.palette then
		t.palette = obj.palette
	end
	t.fgcolor = obj.fgcolor
	t.bgcolor = obj.bgcolor
	t.position = { x = box.x, y = box.y, z = box.z }
	t.rotation = { r = box.r, x = box.rox, y = box.roy }
	t.scale = { x = box.sx, y = box.sy }
	t.style = makeCopy(obj.style)
	if obj._getCfg then
		for _, v in ipairs(obj._getCfg) do v(obj, t)	end
	end	
	return t
end

local function extendDrawCfg(obj, getfunc, setfunc)
	if getfunc then
		if not obj._getCfg then obj._getCfg = {} end
		tinsert(obj._getCfg, getfunc)
	end
	if setfunc then
		if not obj._setCfg then obj._setCfg = {} end
		tinsert(obj._setCfg, setfunc)
	end
end

-- install all drawable functions
local function installDrawable(obj)
	obj.color = color
	obj.visible = visible
	obj.position = position
	obj.scale = scale
	obj.style = style
	obj.rotate = rotate
	obj.setDrawCfg = setDrawCfg
	obj.getDrawCfg = getDrawCfg
	obj.extendDrawCfg = extendDrawCfg
	obj.localPalette = localPalette
end

-- constructor code for all the things, we just assign the local functions to 
-- created objects in the 'constructor' create() function for each object type
return {
	_setxhen = function(hen)
		xhen = hen
	end,
	-- ********************************************************************************
	-- drawable entities
	drawable = function(obj, cfg)
		installBase(obj)
		installDrawable(obj)
	end,
	-- entities and derived
	entity = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	shadow = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	screen = function(obj, cfg)
		installBase(obj)
		installDrawable(obj)
		xhen:add('_draw', obj)
		xhen:add('_update', obj)
		obj.addLayer = addLayer
		obj.removeLayer = removeLayer
		obj.setShader = setScreenShader
		obj.getShader = getShader
		obj.clear = screenClear
	end,
	-- ********************************************************************************
	-- our layer types
	layer = function(obj, cfg)
		installBase(obj)
		installDrawable(obj)
		installLayer(obj)
	end,
	rasterlayer = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
		installRasterLayer(obj)
		obj.targetpacking = 0.7
		obj.limit = math.min(LoveLimit.texturesize, 16384)
		if obj.inherit then
			-- inherit shared raster memory of another layer
			obj._data = obj.inherit.data
			obj.raster = obj.inherit.raster
			obj.rasterbox = obj.inherit.rasterbox
		else
			-- create the default image memory for the raster we draw from
			local sz = math.floor(math.sqrt(obj.megabytes * 1048576 * 0.25))
			obj.raster = love.image.newImageData(sz, sz, 'rgba8')
			obj.rasterbox.w = sz
			obj.rasterbox.h = sz
		end
	end,
	basiclayer = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
		installLayer(obj)
	end,
	userlayer = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
		installLayer(obj)
		if not obj.userDraw then error('create() userlayer must supply a userDraw function') end
	end,
	-- ********************************************************************************
	-- entities that go in the layer and therefore onto the screen
	art = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	image = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	sprite = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	bitmap = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	bitmaptext = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	ttftext = function(obj, cfg) 
		installBase(obj)
		installDrawable(obj)
	end,
	-- ********************************************************************************
	-- nonentities and derived
	nonentity = function(obj, cfg) 
		installBase(obj)
	end,
	duplicate = function(obj, cfg) 
		installBase(obj)
	end,
	visual = function(obj, cfg) 
		installBase(obj)
	end,
	shader = function(obj, cfg) 
		installBase(obj)
	end,
	config = function(obj, cfg) 
		installBase(obj)
	end,
	sample = function(obj, cfg) 
		installBase(obj)
	end,
	stream = function(obj, cfg) 
		installBase(obj)
	end,
	map = function(obj, cfg) 
		installBase(obj)
	end,
	tiling = function(obj, cfg) 
		installBase(obj)
	end,
}