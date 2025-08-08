-- internal libraries not exposed to the end-user
local shash = require '❤️.shash'

-- luajit string buffers
local buffer = require 'string.buffer'

-- luajit table extensions
local tclear = require 'table.clear'
local tnew = require 'table.new'

-- locals linking into love modules
local lfsRead = love.filesystem.read
local lfsDir = love.filesystem.getDirectoryItems
local liNewImageData = love.image.newImageData
local lsNewSoundData = love.sound.newDecoder
local lgclear = love.graphics.clear
local lgsetColor = love.graphics.setColor

-- local functions since they are called a lot
local tinsert = table.insert
local tremove = table.remove

-- a local to hold a reference to hen itself
local xhen, xhenstate, xhenscreen, xhenclass, xhenkilled, xhenlogic, prototable

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
local blank = util.blank
local null = util.null
local insertionSort = util.insertionSort
local mergeSort = util.mergeSort

-- create an index for a classed object
local function indexClass(obj)
	if obj.classid ~= -1 then return end
	local t = subtable(xhenclass, obj.classname)
	tinsert(t, obj)
	obj.classid = #t
end

-- remove an index for a classed object
local function unindexClass(obj)
	if obj.classid == -1 then return end
	remove(xhenclass, obj.classid)
	obj.classid = -1
end

-- iterate over all logic given an event (over entries in table t)
local function doLogic(t, event, a, b, c, d, e, f)
	for k, v in pairs(t) do
		local name = event .. k
		if xhenlogic[name] then
			for _, l in ipairs(xhenlogic[name]) do
				if l[name] then
					for _, o in ipairs(v) do
						l[name](l, xhen, o, a, b, c, d, e, f)
					end
				end
			end
		end
	end
end

-- iterate over all class logic given an event
local function doClassLogic(event, obj, a, b, c, d, e, f)
	if not obj.classname then return end
	local name = event .. '|' .. obj.classname
	if xhenlogic[name] then
		for _, l in ipairs(xhenlogic[name]) do
			if l[name] then
				l[name](l, xhen, obj, a, b, c, d, e, f)
			end
		end
	end
end

-- iterate over all root/call logic given a name
-- we denote root logic names with a bang, or ! at the end
local function doRootLogic(name, a, b, c, d, e, f)
	if xhenlogic[name] then
		for _, l in ipairs(xhenlogic[name]) do
			if l[name] then
				l[name](l, xhen, name, a, b, c, d, e, f)
			end
		end
	end
end

-- ********************************************************************************
-- low level asset loading functions
local function loadImageData(hen, fname) return liNewImageData(fname) end
local function loadSoundData(hen, fname) return lsNewSoundData(fname) end
local function loadBinaryData(hen, fname) return lfsRead(fname) end
local function loadlz4Data(hen, fname)
	return love.data.decompress('data', 'lz4', love.filesystem.newFileData(fname))
end
local function loadzlibData(hen, fname)
	return love.data.decompress('data', 'zlib', love.filesystem.newFileData(fname))
end
local function loadgzData(hen, fname)
	return love.data.decompress('data', 'gzip', love.filesystem.newFileData(fname))
end
local function loadFontData(hen, fname)
	return love.filesystem.newFileData(fname)
end
local function loadJsonData(hen, fname)
	return hen.lib.json.decode(lfsRead(fname))
end
local function loadIniData(hen, fname)
	return hen.lib.lip.decode(lfsRead(fname))
end
-- loader function for lua code, returns the code chunk function
local function loadLuaCode(hen, fname)
	local code = lfsRead(fname)
	local ret = nil
	if code then ret = assert(loadstring(code)) end
	return ret
end

-- add a loaded table resource to the archive of loaded stuff
local function addArchiveTable(hen, name, t)
	local grp, fn, ext = string.match(name, "^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$")
	if grp == '/' then grp = '/~/' end
	subtable(hen.archive, dir2dot(grp:sub(2, -2)))[fn] = t
end

-- read an apps directory tree
local function dirTree(hen, dir, t)
	local ret
	if not t then
		t = {}
		ret = t
	end
	if not dir then
		dir = '/'
		hen.dir = hen.dir or t
	end
	tinsert(t, dir)
	for _, v in ipairs(lfsDir(dir)) do
		local n = dir .. v
		if not n:find('/.', 1, true) then
			if love.filesystem.getInfo(n).type == 'directory' and n ~= '/❤️' then
				dirTree(hen, dir .. v .. '/', t)
			end
		end
	end
	return ret
end

-- load code from a directory
local function dirLoadCode(hen, v)
	-- load a state.lua file if present
	local ret = loadLuaCode(hen, v .. 'state.lua')
	if type(ret) == 'function' then
		addArchiveTable(hen, v .. 'state.lua', ret)
	end
	-- handle _code.lua if present
	ret = loadLuaCode(hen, v .. '_code.lua')
	if type(ret) == 'boolean' then
		if ret == true then
			-- true, load all the code files in this directory
			for _, n in ipairs(lfsDir(v)) do
				if n:sub(-4) == '.lua' then
					hen.addArchive(hen, v .. n)
				end
			end
		else
			-- false, store all code files into storage for later loading
			for _, n in ipairs(lfsDir(v)) do
				if n:sub(-4) == '.lua' then
					hen.addStorage(hen, v .. n)
				end
			end
		end
	elseif type(ret) == 'table' then
		-- the table tells us where to load the code files into storage
		for k, t in pairs(ret) do
			if type(t) ~= 'table' then error('improperly formatted table returned by: ' .. v .. '_code.lua') end
			for n, v in pairs(t) do
				subtable(hen.storage, k)[n] = v
			end
		end
	elseif type(ret) == 'nil' then
		if HenConfig.hen.autostore then -- if we are configured to autostore, so that
			for _, n in ipairs(lfsDir(v)) do
				if n:sub(-4) == '.lua' then
					hen.addStorage(hen, v .. n)
				end
			end
		end
	else
		error('improper type returned from: ' .. v .. '_code.lua')
	end
end

-- load data from a directory
local function dirLoadData(hen, v)
	local ret = loadLuaCode(hen, v .. '_data.lua')
	if type(ret) == 'boolean' then
		if ret == true then
			-- true, load all the data files in this directory
			for _, n in ipairs(lfsDir(v)) do
				hen.addArchive(hen, v .. n)
			end
		else
			-- false, store all data files into storage for later loading
			for _, n in ipairs(lfsDir(v)) do
				hen.addStorage(hen, v .. n)
			end
		end
	elseif type(ret) == 'table' then
		-- the table tells us where to load the data files into storage
		for k, t in pairs(ret) do
			if type(t) ~= 'table' then error('improperly formatted table returned by: ' .. v .. '_code.lua') end
			for n, v in pairs(t) do
				subtable(hen.storage, k)[n] = v
			end
		end
	elseif type(ret) == 'nil' then
		if HenConfig.hen.autostore then -- if we are configured to autostore, so that
			for _, n in ipairs(lfsDir(v)) do
				print(v .. n)
				hen.addStorage(hen, v .. n)
			end
		end
	else
		error('improper type returned from: ' .. v .. '_data.lua')
	end
end

local function canLoad(hen, fname)
	return hen.loader[fname:sub(-4)] ~= nil
end

-- get an object from the current state
local function get(hen, grp, name, copy)
	grp, name = breakup(grp, name)
	if hen.state[grp] and hen.state[grp][name] then
		local obj = hen.state[grp][name]
		while obj.alias do obj = obj.alias end
		if not obj then return null end
		if copy then
			return makeCopy(obj)
		else
			return obj
		end
	end
end

-- get an object from the archive
local function read(hen, grp, name, copy)
	grp, name = breakup(grp, name)
	if hen.archive[grp] and hen.archive[grp][name] then
		if copy then
			return makeCopy(hen.archive[grp][name])
		else
			return hen.archive[grp][name]
		end
	end
end

-- get an object from the archive and install it into the state
local function install(hen, from_grp, from_name, to_grp, to_name, copy)
	local obj = blank
	from_grp, from_name = breakup(from_grp, from_name)
	to_grp, to_name = breakup(to_grp, to_name)
	if not to_name then
		if hen.archive[from_grp] and hen.archive[from_grp][from_name] then
			obj = hen.archive[from_grp][from_name]
			if copy then
				tinsert(subtable(hen.state, to_grp), makeCopy(obj))
			else
				tinsert(subtable(hen.state, to_grp), obj)
			end
		end
	else
		if hen.archive[from_grp] and hen.archive[from_grp][from_name] then
			obj = hen.archive[from_grp][from_name]
			if copy then
				subtable(hen.state, to_grp)[to_name] = makeCopy(obj)
			else
				subtable(hen.state, to_grp)[to_name] = obj
			end
		end
	end
	doClassLogic('install', obj)
end

-- remove any object from the state
local function uninstall(hen, grp, name)
	grp, name = breakup(grp, name)
	if hen.state[grp] and hen.state[grp][name] then
		doClassLogic('uninstall', hen.state[grp][name])
		if type(name) == 'number' then
			remove(hen.state[grp], name)
		else
			hen.state[grp][name] = nil
		end
	end
end

-- install a created object into our state
local function installInto(hen, to_grp, to_name, obj)
	to_grp, to_name = breakup(to_grp, to_name)
	if to_name then
		subtable(hen.state, to_grp)[to_name] = obj
	else
		tinsert(subtable(hen.state, to_grp), obj)
	end
	doClassLogic('install', obj)
end

-- load and return a resource from a file
local function loadResource(hen, fname, noerror)
	local grp, fn, ext = string.match(fname, "^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$")
	local loader = hen.loader[ext:lower()]
	if not loader and not noerror then error('hen has no registered loader for: ' .. ext) end
	if not loader then loader = loadBinaryData end
	return loader(hen, trimPath(fname))
end

-- add a resource to the archive of loaded stuff
local function addArchive(hen, name)
	local grp, fn, ext = string.match(name, "^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$")
	local r = loadResource(hen, name)
	if not r then error('hen could not load: ' .. name) end
	if grp == '/' then grp = '/~/' end
	subtable(hen.archive, dir2dot(grp:sub(2, -2)))[fn] = r
end

-- add a resource to the storage bank of loadable stuff
local function addStorage(hen, name)
	local grp, fn, ext = string.match(name, "^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$")
	if grp == '/' then grp = '/~/' end
	if grp == nil or fn == nil then return end
	subtable(hen.storage, dir2dot(grp:sub(2, -2)))[fn] = name
end

-- copy a defined group in hen.archive .storage .state
local function copyGroup(hen, what, from, to)
	local hg = hen[what]
	if hg[to] then
		copyInto(hg[from], hg[to])
	else
		hg[to] = makeCopy(hg[from])
	end
	hg[from] = nil
end

-- alias to a defined group in hen.archive .storage .state
local function aliasGroup(hen, what, from, to)
	local hg = hen[what]
	hg[to] = hg[from]
end

-- do we have an entry in the loaded archive
local function hasEntry(hen, grp, name)
	grp, name = breakup(grp, name)
	if hen.archive[grp] and hen.archive[grp][name] then return true end
	return false
end

-- enter a state (from the archive, creates a state entity in the global state)
local function enter(hen, grp, name, cfg)
	grp, name = breakup(grp, name)
	if get(hen, grp, name) then
		error('object [' .. combine(grp, name) .. '] already exists and cannot be entered')
	end
	local fn = read(hen, grp, name)
	if type(fn) ~= 'function' then
		error('object [' .. combine(grp, name) .. '] is not function code, cannot be entered')
	else
		local obj = fn()
		if obj.type ~= 'code' or obj.subtype ~= 'state' then
			error('object [' .. combine(grp, name) .. '] is not a code state and cannot be entered')
		end
		if obj.name then
			subtable(hen.state, grp)[obj.name] = obj
		else
			tinsert(subtable(hen.state, grp), obj)
		end
		if obj.style == 'functional' then
			if not obj.enter or type(obj.enter) ~= 'function' then
				error('object [' .. combine(grp, name) .. "] does not implement an .enter() function")
			end
			if not obj.exit or type(obj.exit) ~= 'function' then
				error('object [' .. combine(grp, name) .. "] does not implement an .exit() function")
			end
			obj:enter(hen, cfg)
		elseif obj.style == 'mapped' then
			-- TODO
		else
			error('invalid .style definition in [' .. combine(grp, name) .. "], must be 'functional' or 'mapped'")
		end
		if obj.classname then indexClass(obj) end
		doClassLogic('enter', obj)
	end
end

-- exit a state
local function exit(hen, grp, name)
	grp, name = breakup(grp, name)
	if hen.state[grp] then
		local obj = hen.state[grp][name]
		if not obj then
			error('object [' .. combine(grp, name) .. '] does not exist and cannot be exited')
		end
		hen.state[grp][name] = nil
		if obj.type ~= 'code' or obj.subtype ~= 'state' then
			error('object [' .. combine(grp, name) .. '] is not a code state and cannot be exited')
		end
		obj:exit(hen)
		doClassLogic('exit', obj)
		if obj.classname then unindexClass(obj) end
	end
end

-- load a library
local function hload(hen, grp, name, cfg)
	grp, name = breakup(grp, name)
	if get(hen, grp, name) then
		error('object [' .. combine(grp, name) .. '] already exists and cannot be loaded')
	end
	local fn = read(hen, grp, name)
	if type(fn) ~= 'function' then
		error('object [' .. combine(grp, name) .. '] is not function code, cannot be loaded')
	else
		local obj = fn()
		if obj.type ~= 'code' or obj.subtype ~= 'library' then
			error('object [' .. combine(grp, name) .. '] is not a code library and cannot be loaded')
		end
		if obj.name then
			if subtable(hen.state, grp)[obj.name] then
				error('object [' .. combine(grp, name) .. '] is already loaded, you cannot load a loaded library')
			end
			subtable(hen.state, grp)[obj.name] = obj
		else
			error('object [' ..
			combine(grp, name) .. '] has no name, and nameless code libraries and not currently supported')
		end
		if obj.style == 'functional' then
			if not obj.load or type(obj.load) ~= 'function' then
				error('object [' .. combine(grp, name) .. "] does not implement an .enter() function")
			end
			if not obj.unload or type(obj.unload) ~= 'function' then
				error('object [' .. combine(grp, name) .. "] does not implement an .exit() function")
			end
			obj:load(hen, cfg)
		elseif obj.style == 'mapped' then
			-- TODO
		else
			error('invalid .style definition in [' .. combine(grp, name) .. "], must be 'functional' or 'mapped'")
		end
		if obj.classname then indexClass(obj) end
		doClassLogic('load', obj)
	end
end

-- unload a library
local function hunload(hen, grp, name)
	grp, name = breakup(grp, name)
	if hen.state[grp] then
		local obj = hen.state[grp][name]
		if not obj then
			error('object [' .. combine(grp, name) .. '] does not exist and cannot be unloaded')
		end
		hen.state[grp][name] = nil
		if obj.type ~= 'code' or obj.subtype ~= 'library' then
			error('object [' .. combine(grp, name) .. '] is not a code library and cannot be unloaded')
		end
		obj:unload(hen)
		doClassLogic('unload', obj)
		if obj.classname then unindexClass(obj) end
	end
end

-- create a new object
local function create(hen, name, prototype, cfg)
	local ret = {
		group = '*',
		name = name
	}
	buildSupers(prototable, prototype, ret)
	if cfg then copyInto(cfg, ret) end
	ret:create(hen, cfg)
	if ret.classname then indexClass(ret) end
	return ret
end

-- destroy a given object
local function destroy(hen, grp, name)
	grp, name = breakup(grp, name)
	if hen.state[grp] then
		local obj = hen.state[grp][name]
		if obj then obj:destroy(hen, grp, name) end
		if type(name) == 'number' then
			remove(hen.state[grp], name)
		else
			hen.state[grp][name] = nil
		end
		if obj.classname then unindexClass(obj) end
	end
end

-- mark an object as killed
local function kill(hen, objgrp, name)
	if name then
		objgrp, name = breakup(objgrp, name)
		if hen.state[objgrp] then
			local obj = hen.state[objgrp][name]
			while obj.alias do obj = obj.alias end
			if obj.dead then return end
			obj.dead = true
			doClassLogic('kill', obj)
			tinsert(xhenkilled, obj)
		end
	else
		if objgrp.dead then return end
		objgrp.dead = true
		doClassLogic('kill', objgrp)
		tinsert(xhenkilled, objgrp)
	end
end

-- create and install a new object into our state
local function createInto(hen, to_grp, to_name, prototype, cfg)
	to_grp, to_name = breakup(to_grp, to_name)
	if hen.nameReserved[to_grp] then error('group `' .. to_grp .. '` is reserved for internal use and cannot be used') end
	local obj = create(hen, to_name, prototype, cfg)
	if to_name then
		subtable(hen.state, to_grp)[to_name] = obj
	else
		tinsert(subtable(hen.state, to_grp), obj)
	end
	return obj
end

-- handle new class additions
local function classify(hen, obj)
	if obj.classname then indexClass(obj) end
end

-- handle class removals
local function declassify(hen, obj)
	if obj.classname then unindexClass(obj) end
end

-- dispatch an event
local function dispatch(hen, name, a, b, c, d, e, f)
	doRootLogic(name, a, b, c, d, e, f)
end

-- enable a hen option
local function enable(hen, option)
	hen.enabled[option] = true
	doRootLogic('enable!', option)
end

-- enable a hen option
local function disable(hen, option)
	hen.enabled[option] = false
	doRootLogic('disable!', option)
end

-- simple z sort function for draw usage of screens below
local function zless(a, b) return a.z < b.z end

-- draw the state
local function stateDraw()
	-- there is a table in our state called _draw, which is a list of
	-- tables (usually screen instances) to call .draw(self, hen) on
	local dps = xhenstate['_draw']
	-- sort and the drawable objects by z
	insertionSort(dps, 1, #dps, zless)
	-- clear the screen and set the normal draw color
	lgclear(xhen.bgcolor)
	lgsetColor(xhen.fgcolor)
	-- make everything draw
	for i, v in ipairs(dps) do
		v._draw_pos = i
		v:draw(xhen)
	end
end

-- update the state
local function stateUpdate(dt)
	xhen.clock = xhen.clock + (dt * xhen.clockspeed)
	xhen.clockdt = dt
	-- see if we have update logic to call for hen itself
	doRootLogic('update!')
	-- see if we have update logic to call for classed objects
	doLogic(xhenclass, 'update|')
	-- see if we have update logic to call for grouped objects
	doLogic(xhenstate, 'update:')
	-- there is a table in our state called _update, which is an ordered list of
	-- tables to call .update(self, hen, dt) on
	local ups = xhenstate['_update']
	if not get(xhen, 'screen', 'MainScreen') then
		error("stateUpdate(): hen has no screen:MainScreen!")
	end
	for _, v in ipairs(ups) do
		v:update(xhen, dt)
	end
	-- remove killed objects
	for _, obj in ipairs(xhenkilled) do
		if obj.destroy then obj:destroy(xhen) end
	end
	tclear(xhenkilled)
end

local function add(hen, what, obj)
	tinsert(subtable(hen.state, what), obj)
	obj[what .. '_pos'] = #hen.state[what]
end

local function remove(hen, what, obj)
	if not obj[what .. '_pos'] then return end
	tremove(subtable(hen.state, what), obj[what .. '_pos'])
	obj[what .. '_pos'] = false
end

local function slot(hen, what, obj)
	return obj[what .. '_pos']
end

local function addLogic(hen, logic)
	if logic._pos then error('Cannot add the same logic twice!') end
	local pos = {}
	for k, v in pairs(logic) do
		if not xhenlogic[k] then xhenlogic[k] = {} end
		local t = xhenlogic[k]
		tinsert(t, logic)
		pos[k] = #t
	end
	logic._pos = pos
end

local function removeLogic(hen, logic)
	if not logic._pos then error('Cannot remove logic never added or already removed!') end
	for k, v in pairs(logic._pos) do
		remove(xhenlogic[k], v)
	end
	logic._pos = false
end

-- ********************************************************************************
-- assemble!
return function(hen)
	if Log then Log('---\nhen()\n') end
	-- hen's internal function table
	hen.dirTree = dirTree
	hen.dirLoadCode = dirLoadCode
	hen.dirLoadData = dirLoadData
	hen.addArchive = addArchive
	hen.canLoad = canLoad
	hen.copyGroup = copyGroup
	hen.aliasGroup = aliasGroup
	hen.addStorage = addStorage
	hen.hasEntry = hasEntry
	hen.classify = classify
	hen.declassify = declassify
	hen.enter = enter
	hen.exit = exit
	hen.get = get
	hen.read = read
	hen.create = create
	hen.destroy = destroy
	hen.kill = kill
	hen.defaults = defaults
	hen.load = hload
	hen.unload = hunload
	hen.install = install
	hen.installInto = installInto
	hen.createInto = createInto
	hen.uninstall = uninstall
	hen.dispatch = dispatch
	hen.enable = enable
	hen.disable = disable
	hen.add = add
	hen.remove = remove
	hen.addLogic = addLogic
	hen.removeLogic = removeLogic
	hen.doClassLogic = doClassLogic
	-- hen's file loaders
	hen.loader['.lua'] = loadLuaCode
	hen.loader['.bmp'] = loadImageData
	hen.loader['.png'] = loadImageData
	hen.loader['.tga'] = loadImageData
	hen.loader['.jpg'] = loadImageData
	hen.loader['.jpeg'] = loadImageData
	hen.loader['.wav'] = loadSoundData
	hen.loader['.mp3'] = loadSoundData
	hen.loader['.ogg'] = loadSoundData
	hen.loader['.oga'] = loadSoundData
	hen.loader['.mod'] = loadSoundData
	hen.loader['.it'] = loadSoundData
	hen.loader['.s3m'] = loadSoundData
	hen.loader['.dmf'] = loadSoundData
	hen.loader['.xm'] = loadSoundData
	hen.loader['.lz4'] = loadlz4Data
	hen.loader['.gz'] = loadgzData
	hen.loader['.z'] = loadzlibData
	hen.loader['.bin'] = loadBinaryData
	hen.loader['.glsl'] = loadBinaryData
	hen.loader['.json'] = loadJsonData
	hen.loader['.ini'] = loadIniData
	hen.loader['.ttf'] = loadFontData
	-- state reserved group names
	hen.nameReserved = {
		draw = true,
		_draw = true,
		update = true,
		_update = true,
		null = true,
		['~'] = true
	}
	-- tables we require
	hen.prototype = require '❤️.proto'
	hen.prototype._create._setxhen(hen)
	hen.prototype._destroy._setxhen(hen)
	hen.prototype._update._setxhen(hen)
	hen.prototype._draw._setxhen(hen)
	hen.state.draw = stateDraw
	hen.state._draw = {}
	hen.state.update = stateUpdate
	hen.state._update = {}
	hen.event = {}
	-- the global clock
	hen.clock = 0
	hen.clockspeed = 1
	-- store linkage for later
	xhen = hen
	xhenstate = hen.state
	xhenscreen = hen.state.screen
	xhenclass = hen.classindex
	xhenlogic = hen.logic
	xhenkilled = hen.killed
	-- build our prototype system for objects
	prototable = hen.prototype
	-- create the MainScreen
	local sx, sy, sw, sh = 0, 0, love.graphics.getDimensions()
	hen:createInto('screen', 'MainScreen', 'screen', {
		classname = 'screen',
		classid = -1,
		visible = true,
		dead = false,
		bgcolor = { 0, 0, 0, 0 },
		fgcolor = { 1, 1, 1, 1 },
		box = { x = sx, y = sy, z = 1, w = sw, h = sh }
	})
	-- configure from HenConfig.hen
	hen.bgcolor = HenConfig.hen.bgcolor or { 0, 0, 0, 0 }
	hen.fgcolor = HenConfig.hen.fgcolor or { 1, 1, 1, 1 }
	-- setup the logo
	addArchive(hen, '/❤️/logo/heart.png')
	addArchive(hen, '/❤️/logo/heart_pattern.png')
	addArchive(hen, '/❤️/logo/state.lua')
	aliasGroup(hen, 'archive', '❤️.logo', 'HenLogo')
end
