--[[
	Prototypes for all objects in Heartful Engine
]]

-- ********************************************************************************
-- get utility functions
local util = require '❤️.util'
local subTable = util.subtable
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
local noCall = util.noCall
local null = util.null

-- include a lot of base code we organize by it's use
local create = require '❤️.create'
local destroy = require '❤️.destroy'
local draw = require '❤️.draw'
local update = require '❤️.update'

-- ********************************************************************************
--[[
	prototypes

	These are objects you can create in the engine, and are all meant to be either
	things you draw and interact with, or collections of such.

	One thing to keep in mind is that entities aren't optimized to use a small memory
	footprint. So you wouldn't really want to use the entity:draw() model for say:
	a particle system. To do something like that put it inside your own more optimized
	custom entity where you can provide your own :draw() function
]]
local proto = {
	-- the prototype of anything we can draw
	['drawable'] = {
		visible = true,
		bgcolor = { 0, 0, 0, 0 },
		fgcolor = { 1, 1, 1, 1 },
		style = { fill = false, outline = false },
		box = { x = 0, y = 0, z = 0, w = 0, h = 0, sx = 1, sy = 1, r = 0, rox = 0, roy = 0 }
	},
	-- the prototype of all entities, which are things that can be drawn
	-- on the screen and interacted with
	['entity'] = {
		super = 'drawable',
		isEntity = true,
		name = false,
		layer = false,
		classname = false,
		classid = -1,
		id = -1,
		dead = false,
		data = false,
		destroyed = false,
		children = {}
	},
	-- an alias to another entity
	['shadow'] = {
		super = 'entity',
		alias = false
	},
	-- a screen is a container for one or more layers, which are drawn to the
	-- application window
	['screen'] = {
		super = 'entity',
		classname = 'screen',
		type = 'screen',
		target = false,
		bgcolor = { 1, 1, 1, 1 },
		style = { fill = 'fillcolor', znodepth = false },
		layer = {}
	},
	-- base type of all layers you can add to a screen
	['layer'] = {
		super = 'entity',
		classname = 'layer',
		type = 'layer',
		screen = false,
		shader = false,
		bgcolor = { 1, 1, 1, 1 },
		style = { znodepth = false, shashsize = 0 },
		sort = false,
		entity = {}
	},
	-- raster layer contains only raster (image/sprite) objects and a raster image
	-- to draw them from
	['rasterlayer'] = {
		super = 'layer',
		subtype = 'raster',
		type = 'layer',
		rasterbox = { x = 0, y = 0, w = 0, h = 0 },
		rastermap = {},
		rasterborder = 0,
		raster = false,
		megabytes = 4,
		grow = true
	},
	-- basic layer makes no assumptions, and can contain any object type
	['basiclayer'] = {
		super = 'layer',
		subtype = 'basic',
		type = 'layer',
	},
	-- user layer has custom user update and draw functions
	['userlayer'] = {
		super = 'layer',
		subtype = 'user',
		type = 'layer',
	},
	-- shapes draws one or more shapes/visuals as an entity
	['art'] = {
		super = 'entity',
		type = 'art',
		subtype = 'nonraster',
		element = {}
	},
	-- a raster image
	['image'] = {
		super = 'entity',
		type = 'image',
		subtype = 'raster',
		imgdata = false,
		raster = false,
		quad = false
	},
	-- a raster sprite
	['sprite'] = {
		super = 'entity',
		type = 'sprite',
		subtype = 'raster',
		quad = {},
		animation = {},
		raster = false,
		imgdata = false,
	},
	-- a raster bitmap, just like an image but we can draw to it
	['bitmap'] = {
		super = 'entity',
		type = 'bitmap',
		subtype = 'raster',
		raster = false,
		imgdata = false,
		quad = false
	},
	-- an instance of text drawn from a bitmap font
	['bitmaptext'] = {
		super = 'entity',
		type = 'font',
		subtype = 'raster',
		raster = false,
		imgdata = false,
		quad = {}
	},
	-- an instance of text drawn from a ttf font
	['ttftext'] = {
		super = 'entity',
		type = 'font',
		subtype = 'nonraster',
		quad = {}
	},
	-- the prototype of all entities, which are things that cannot be drawn
	['nonentity'] = {
		name = false,
		isEntity = false,
		classname = false,
		classid = -1,
		id = -1,
		dead = false,
		data = false,
		destroyed = false,
		children = {}
	},
	-- an alias to another nonentity
	['duplicate'] = {
		super = 'nonentity',
		type = 'duplicate',
		alias = false
	},
	-- a custom user drawn visual
	['visual'] = {
		super = 'nonentity',
		type = 'visual'
	},
	-- a shader you can add to a layer
	['shader'] = {
		super = 'nonentity',
		type = 'shader'
	},
	-- a config to define something
	['config'] = {
		super = 'nonentity',
		type = 'config'
	},
	-- a sound sample
	['sample'] = {
		super = 'nonentity',
		type = 'sample'
	},
	-- a sound stream
	['stream'] = {
		super = 'nonentity',
		type = 'stream'
	},
	-- a map of entities
	['map'] = {
		super = 'nonentity',
		type = 'map'
	},
	-- a tiling pattern map
	['tiling'] = {
		super = 'map',
		type = 'tiling'
	},
	-- ********************************************************************************
	-- helper functions
	buildSupers = buildSupers,
	_create = create,
	_destroy = destroy,
	_update = update,
	_draw = draw,
}

for k, v in pairs(proto) do -- map the functions for all objects
	if type(v) == 'table' then
		v.create = create[k] or noCall
		v.destroy = destroy[k] or noCall
		v.update = update[k] or noCall
		v.draw = draw[k] or noCall
	end
end -- now all proto entries have .create() and such calls

return proto
