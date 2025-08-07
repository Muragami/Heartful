--[[
	Here we build the draw routines of objects in the Heartful engine
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
local drawtype = util.drawtype
local mergeSort = util.mergeSort

-- ********************************************************************************
-- love linkage
local lgarc = love.graphics.arc
local lgline = love.graphics.line
local lgrect = love.graphics.rectangle
local lgellipse = love.graphics.ellipse
local lgpolygon = love.graphics.polygon
local lgdraw = love.graphics.draw
local lgpoints = love.graphics.points
local lgprintf = love.graphics.printf
local lgcolor = love.graphics.setColor

-- local functions since they are called a lot
local tinsert = table.insert
local tremove = table.remove

local xhen = false

-- ********************************************************************************
-- low-level stuff
local function zlesseq(a, b) return a.box.z <= b.box.z end

local fgcolor, bgcolor, fgblend, bgblend
local white = { 1, 1, 1, 1 }
local fgblend = { 1, 1, 1, 1 }
local bgblend = { 1, 1, 1, 1 }

local function initColor(fcol, bcol)
	fgcolor = { fcol }
	fgblend = fcol
	bgcolor = { bcol }
	bgblend = bcol
end

local function pushFgColor(col)
	fgblend[1] = fgblend[1] * col[1]
	fgblend[2] = fgblend[2] * col[2]
	fgblend[3] = fgblend[3] * col[3]
	fgblend[4] = fgblend[4] * col[4]
	tinsert(fgcolor, fgblend)
end

local function popFgColor()
	tremove(fgcolor)
	local c = fgcolor[#fgcolor]
	fgblend[1] = c[1]
	fgblend[1] = c[1]
	fgblend[1] = c[1]
	fgblend[1] = c[1]
end

local function pushBgColor(col)
	bgblend[1] = bgblend[1] * col[1]
	bgblend[2] = bgblend[2] * col[2]
	bgblend[3] = bgblend[3] * col[3]
	bgblend[4] = bgblend[4] * col[4]
	tinsert(bgcolor, bgblend)
end

local function popBgColor()
	tremove(bgcolor)
	local c = bgcolor[#bgcolor]
	bgblend[1] = c[1]
	bgblend[1] = c[1]
	bgblend[1] = c[1]
	bgblend[1] = c[1]
end

local function setFgColor(col)
	lgcolor(col[1] * fgblend[1], col[2] * fgblend[2], col[3] * fgblend[3], col[4] * fgblend[4])
end

local function setBgColor(col)
	lgcolor(col[1] * bgblend[1], col[2] * bgblend[2], col[3] * bgblend[3], col[4] * bgblend[4])
end

-- ********************************************************************************
-- draw the layer
local theShader, prevShader

local function drawLayer(obj)
	-- assign a shader if provided
	if theShader ~= obj.shader then
		if theShader then prevShader = theShader end
		love.graphics.setShader(obj.shader)
		theShader = obj.shader
	end
	-- if we have a sort, do that
	if obj.sort then
		obj.sort.resolve(obj, 'entity', obj.sort.lesseq)
	end
	-- are we buffering to a canvas?
	if obj.canvas then
		love.graphics.setCanvas(obj.canvas)
		love.graphics.clear()
	else
	end
	-- setup color blending as needed
	if obj.fgcolor then pushFgColor(obj.fgcolor) end
	if obj.bgcolor then pushBgColor(obj.bgcolor) end
	-- iterate over all entities and draw them
	for _, e in ipairs(obj.entity) do
	end
	-- remove color blending as needed
	if obj.fgcolor then popFgColor() end
	if obj.bgcolor then popBgColor() end
	if obj.canvas then
		love.graphics.setCanvas()
		-- draw the layer
		local box = obj.box
		love.graphics.setBlendMode("alpha", "premultiplied")
		lgdraw(obj.canvas, box.x, box.y, box.r, box.sx, box.sy, box.rox, box.roy)
		love.graphics.setBlendMode("alpha")
	end
	-- reset the shader
	if theShader ~= prevShader then
		love.graphics.setShader(prevShader)
		theShader = prevShader
	end

end

-- ********************************************************************************
-- drawing code for all the things
return {
	_setxhen = function(hen)
		xhen = hen
	end,
	shadow = function(obj)
		if not obj.visible then return end
		if obj.alias and obj.alias.draw then
			obj.alias.draw(obj)
		end
	end,
	screen = function(obj)
		if not obj.visible then return end
		-- sort layers by Z
		if not obj.layerbuffer then obj.layerbuffer = {} end
		local b = obj.layerbuffer
		for i = #b, #obj.layer, 1 do
			tinsert(b, null)
		end
		mergeSort(obj.layer, b, zlesseq)
		-- iterate over the layers and tell them to draw
		initColor(obj.fgcolor or white, obj.bgcolor or white)
		for _, layer in ipairs(obj.layer) do
			layer:draw()
		end
	end,
	layer = function(obj)
		if not obj.visible then return end
		drawLayer(obj)
	end,
	rasterlayer = function(obj) 
		if not obj.visible then return end
		drawLayer(obj)
	end,
	basiclayer = function(obj) 
		if not obj.visible then return end
		drawLayer(obj)
	end,
	userlayer = function(obj)
		if not obj.visible then return end
		obj.userDraw(obj)
	end,
	art = function(obj) 
		if not obj.visible then return end
	end,
	image = function(obj) 
		if not obj.visible then return end
	end,
	sprite = function(obj)
		if not obj.visible then return end
	end,
	bitmap = function(obj) 
		if not obj.visible then return end
	end,
	bitmaptext = function(obj) 
		if not obj.visible then return end
	end,
	ttftext = function(obj) 
		if not obj.visible then return end
	end,
}