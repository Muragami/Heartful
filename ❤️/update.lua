--[[
	Here we build the update routines of objects in the Heartful engine
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
local noCall = util.noCall

-- local functions since they are called a lot
local tinsert = table.insert
local tremove = table.remove

-- love linkage
local lgnewquad = love.graphics.newQuad
local lgnewimage = love.graphics.newImage

local xhen = false

-- neaded libs
local maxrects = require '❤️.maxrects'
local ffi = require 'ffi'

-- construct a new maxrects packer class for a new raster layer
local function newPacker(width, height)	return maxrects.new(width, height, false) end

-- function to update all children of an object
local function updateChildren(obj, dt)
	for _, v in ipairs(obj.children) do
		v:update(dt)
	end
end

-- ********************************************************************************
-- raster layer updates

-- draw the black border around the images into a raster map image
local function blackBorder(to, rsize, x, y, w, h, tow)
	local pto = to:getFFIPointer()
	local ffill = ffi.fill
	for dy = 0, rsize - 1, 1 do 			-- top border
		ffill(pto + x * 4 + (dy * tow * 4), (w + rsize * 2) * 4, 0)
	end
	for dy = h, h + rsize - 1, 1 do 	-- bottom border
		ffill(pto + x * 4 + (dy * tow * 4), (w + rsize * 2) * 4, 0)
	end
	for dy = rsize, h, 1 do 					-- left & right borders
		ffill(pto + x * 4 + (dy * tow * 4), rsize * 4, 0)
		ffill(pto + (x + rsize + w) * 4 + (dy * tow * 4), rsize * 4, 0)
	end
end

-- paste 4 byte rgba8 image data into each other, to build the raster map image
local function pasteImage(to, from, x, y, w, h)
	to:paste(from, x, y, 0, 0, w, h)
end

local function trypack(pack, list)
	-- try each available sorting method to pack the list into the packer
	if pack:insertCollection(list, 'SortArea') then return true
		elseif pack:insertCollection(list, 'SortShortSide') then return true
		elseif pack:insertCollection(list, 'SortLongSide') then return true 
		end
	return false
end

-- build a raster (or rebuild) for a raster layer
local function buildRaster(layer)
	if not layer.rasterchange then return end
	local list = layer.rasterlist
	local mapw, maph = layer.rasterbox.w, layer.rasterbox.h 
	local mappixels = mapw * maph
	local expandhorizontal = true
	local contentpixels = 0
	local rborder = layer.rasterborder
	for _, v in ipairs(list) do
		contentpixels = contentpixels + (v[3] * v[4])
	end
	-- target 70% efficiency for initial packing
	while mappixels * layer.targetpacking < contentpixels do
		if expandhorizontal then
			mapw = mapw * 2
			expandhorizontal = false
		else
			maph = maph * 2
			expandhorizontal = true
		end
		mappixels = mapw * maph
	end
	local pack = newPacker(mapw, maph)
	while not trypack(pack, list) and mapw <= layer.limit and maph <= layer.limit do
		-- failure, expand and try again
		if expandhorizontal then
			mapw = mapw * 2
			expandhorizontal = false
		else
			maph = maph * 2
			expandhorizontal = true
		end
		mappixels = mapw * maph
		pack = newPacker(mapw, maph)
	end
	-- did we fail out at too large a size? if so error out
	if mapw > layer.limit or maph > layer.limit then error('rasterlayer:update() failed, size exceeded maximum raster map dimension: ' .. layer.limit) end
	if mapw > layer.rasterbox.w or maph > layer.rasterbox.h then
		-- grow the raster image data as needed
		layer.raster = love.image.newImageData(mapw, maph, 'rgba8', layer._data)
		layer._image = lgnewimage(layer.raster)
		layer.rasterbox.w = mapw
		layer.rasterbox.h = maph
	end
	-- now pack all contents into the image, and rebuild the rastermap
	layer.rastermap = {}
	local rmap = layer.rastermap
	for _, lobj in ipairs(list) do
		local obj = lobj[5] -- array index 5 is the data content in our packer list, so we need that
		if not rmap[obj.imgdata] then
			rmap[obj.imgdata] = 1
		else
			rmap[obj.imgdata] = rmap[obj.imgdata] + 1
		end
		obj.quad = lgnewquad(lobj[1] + rborder, lobj[2] + rborder, lobj[3], lobj[4], mapw, maph)
		obj._image = layer._image
		blackBorder(layer.raster, rborder, lobj[1], lobj[2], lobj[3], lobj[4], mapw)
		pasteImage(layer.raster, obj.imgdata, lobj[1] + rborder, lobj[2] + rborder, lobj[3], lobj[4])
		-- if the object needs to build internal quads, let it do that
		if obj.buildQuads then obj:buildQuads(lobj[1], lobj[2], lobj[3], lobj[4], mapw, maph) end
	end
	layer.filledpercent = contentpixels / (mapw * maph) * 100.0
	layer.rasterchange = false
	layer._image:replacePixels(layer.raster)
end

-- update code for all the things
return {
	_setxhen = function(hen)
		xhen = hen
	end,
	drawable = function(obj, dt)
		updateChildren(obj, dt)
	end,
	entity = function(obj, dt)
		updateChildren(obj, dt)
	end,
	nonentity = function(obj, dt)
		updateChildren(obj, dt)
	end,
	shadow = function(obj, dt)
		if obj.alias and obj.alias.update then
			obj.alias.update(obj)
		end
		updateChildren(obj, dt) 
	end,
	duplicate = function(obj, dt)
		if obj.alias and obj.alias.update then
			obj.alias.update(obj)
		end
		updateChildren(obj, dt) 
	end,
	screen = function(obj, dt)
		for _, v in ipairs(obj.layer) do
			v:update(dt)
		end
		updateChildren(obj, dt)
	end,
	layer = function(obj, dt)
		for _, v in ipairs(obj.entity) do
			v:update(dt)
		end
		updateChildren(obj, dt)
	end,
	rasterlayer = function(obj, dt)
		if obj.rasterchange then buildRaster(obj) end
		if obj.inherit then obj.static = obj.inherit.static end
		for _, v in ipairs(obj.entity) do
			v:update(dt)
		end
		updateChildren(obj, dt)
	end,
	basiclayer = function(obj, dt)
		for _, v in ipairs(obj.entity) do
			v:update(dt)
		end
		updateChildren(obj, dt)
	end,
	userlayer = function(obj, dt)
		for _, v in ipairs(obj.entity) do
			v:update(dt)
		end
		updateChildren(obj, dt)
	end,
	art = function(obj, dt)
		updateChildren(obj, dt)
	end,
	image = function(obj, dt)
		updateChildren(obj, dt)
	end,
	sprite = function(obj, dt)
		updateChildren(obj, dt)
	end,
	bitmap = function(obj, dt)
		updateChildren(obj, dt)
	end,
	bitmaptext = function(obj, dt)
		updateChildren(obj, dt)
	end,
	ttftext = function(obj, dt)
		updateChildren(obj, dt)
	end,
	visual = function(obj, dt)
		updateChildren(obj, dt)
	end,	
	shader = function(obj, dt)
		updateChildren(obj, dt)
	end,
	config = function(obj, dt)
		updateChildren(obj, dt)
	end,
	sample = function(obj, dt)
		updateChildren(obj, dt)
	end,
	stream = function(obj, dt)
		updateChildren(obj, dt)
	end,
	map = function(obj, dt)
		updateChildren(obj, dt)
	end,
	tiling = function(obj, dt)
		updateChildren(obj, dt)
	end,
}