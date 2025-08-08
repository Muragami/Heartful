local hen = {
	_VERSION      = '❤️Heart 0.1.0',
	_DESCRIPTION  = '❤️ Heartful ECS Engine for LÖVE',
	_URL          = 'https://github.com/muragami/Heartful',
	_COPYRIGHT    = 'Copyright (c) 2025 Jason A. Petrasko, muragami, muragami@wishray.com',
	_LICENSE_TYPE = 'MIT',
	_LICENSE      = [[
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
}

-- libraries
local lume = require '❤️.lume'
local inspect = require '❤️.inspect'
local lip = require '❤️.LIP'
local json = require '❤️.json'
local tween = require '❤️.tween'
local lovebird = require '❤️.lovebird'
local util = require '❤️.util'

local null = util.null

-- libraries used by hen, and expose them for the user if they want to dig deeper
hen.lib = { lume = lume, inspect = inspect, tween = tween, lip = lip, lovebird = lovebird, json = json }
-- the current state of the engine, this can be serialized and loaded to resume
hen.state = {}
-- an archive of code modules and data the game can access
hen.archive = {}
-- an table of things that could be loaded into the archive
hen.storage = {}
-- a table of loaders for various file extensions
hen.loader = {}
-- a table of Logic to apply to objects in the system
hen.logic = {}
-- a table of class tables that index classed objects
hen.classindex = {}
-- a table of killed objects to cleanly destroy at the end of an update
hen.killed = {}
-- a table of enabled hen options (event listening, etc)
hen.enabled = {
	event_keyboard = true,
	event_mouse = true,
	event_window = true,
	event_joystick = true,
	event_gamepad = true
}

-- install a simple Log function if verbose is set in game.json
if HenConfig.hen.verbose then
	function Log(txt)
		print(txt)
		if HenConfig.hen.Logging then
			HenLog:write(txt)
		end
	end

	if HenConfig.hen.Logging then
		love.filesystem.write("hen.Log", "")
		HenLog = love.filesystem.newFile("hen.Log", "a")
		HenLog:setBuffer("none")
	end
else
end

-- build hen internally
require '❤️.hen' (hen)

-- ********************************************************************************
-- love linkage follows

function love.load(arg, unfilteredArg)
	LoveLimit = love.graphics.getSystemLimits()
	local entry = null
	if Log then Log('---\nlove.load()\n') end
	-- read in and store the directory tree of this app
	hen:dirTree()
	-- Log Log Log, Log all day
	if Log then Log('---\ndirTree = ' .. inspect(hen.dir) .. '\n') end
	-- now walk that tree and load any core _code and _data
	for _, v in ipairs(hen.dir) do
		if v == '/' then
			-- here we always load all resource files
			-- which are not named 'conf.lua' and 'main.lua'
			for _, f in ipairs(love.filesystem.getDirectoryItems('/')) do
				if f ~= 'conf.lua' and f ~= 'main.lua' then
					if hen:canLoad(f) then
						hen:addArchive(v .. f)
					end
				end
			end
		else
			-- handle if we have a _code.lua and/or _data.lua
			hen:dirLoadCode(v)
			hen:dirLoadData(v)
		end
	end
	-- Log Log Log, Log all day
	if Log then Log('---\nhen.archive = ' .. inspect(hen.archive) .. "\n") end
	if Log then Log('---\nhen.storage = ' .. inspect(hen.storage) .. "\n") end
	-- load anything listed in hen.preload from conf.json
	if HenConfig.hen.preload and type(HenConfig.hen.preload) == 'table' then
		for i, v in ipairs(HenConfig.hen.preload) do
			hen:load(nil, v, HenConfig)
		end
	end
	-- if we have an entry state from conf.json use that
	if HenConfig.hen.enter and type(HenConfig.hen.enter) == 'string' then
		entry = { HenConfig.hen.enter, 'state' }
	else
		-- or if we don't, see if the user supplied a hen.begin function in main.lua
		if not hen.begin or type(hen.begin) ~= 'function' then
			-- no idea what to do, user made a mistake
			error('hen.begin not configured properly, false start, ten yard penalty')
		end
		entry = hen.begin(arg, unfilteredArg)
	end
	-- if we still have no entry point, just error out
	if entry == null then
		error("hen has no entry point defined, did you not set 'enter' in game.json or define a hen.begin() function?")
	end
	-- if we have not disabled the hen Logo, enter that state and link it to the entry point given
	if not HenConfig.hen.noLogo then
		hen:enter('HenLogo', 'state', { args = arg, entry = entry })
	else
		hen:enter(entry[1], entry[2])
	end
	-- Log Log Log, Log all day
	if Log then Log('---\nhen.state = ' .. inspect(hen.state) .. '\n') end
	if Log then Log('---\nhen.classindex = ' .. inspect(hen.classindex) .. '\n') end
end

function love.update(dt)
	if hen.state.update then
		hen.state.update(dt)
	else
		error('hen.state{} does not implement an update(dt) function')
	end
end

function love.draw()
	if hen.state.draw then
		hen.state.draw()
	else
		error('hen.state{} does not implement an draw(dt) function')
	end
end

-- ********************************************************************************
-- love event callbacks (these call into hook tables)

local enable = hen.enabled

function love.keypressed(k, s, i)
	if not enable.event_keyboard then return end
	hen:dispatch('keypressed!', k, s, i)
end

function love.keyreleased(k, s)
	if not enable.event_keyboard then return end
	hen:dispatch('keyreleased!', k, s)
end

function love.textedited(t, s, l)
	if not enable.event_keyboard then return end
	hen:dispatch('textedited!', t, s, l)
end

function love.textinput(t)
	if not enable.event_keyboard then return end
	hen:dispatch('textinput!', t)
end

function love.mousepressed(x, y, b, i, p)
	if not enable.event_mouse then return end
	hen:dispatch('mousepressed!', x, y, b, i, p)
end

function love.mousereleased(x, y, b, i, p)
	if not enable.event_mouse then return end
	hen:dispatch('mousereleased!', x, y, b, i, p)
end

function love.mousemoved(x, y, dx, dy, i)
	if not enable.event_mouse then return end
	hen:dispatch('mousemoved!', x, y, dx, dy, i)
end

function love.wheelmoved(x, y)
	if not enable.event_mouse then return end
	hen:dispatch('wheelmoved!', x, y)
end

function love.directorydropped(p)
	if not enable.event_window then return end
	hen:dispatch('directorydropped!', p)
end

function love.displayrotated(i, o)
	if not enable.event_window then return end
	hen:dispatch('displayrotated!', i, o)
end

function love.filedropped(f)
	if not enable.event_window then return end
	hen:dispatch('filedropped!', f)
end

function love.focus(f)
	if not enable.event_window then return end
	hen:dispatch('focus!', f)
end

function love.mousefocus(f)
	if not enable.event_window then return end
	hen:dispatch('mousefocus!', f)
end

function love.resize(w, h)
	if not enable.event_window then return end
	hen:dispatch('resize!', w, h)
end

function love.visible(f)
	if not enable.event_window then return end
	hen:dispatch('visible!', f)
end

function love.joystickadded(j)
	if not enable.event_joystick then return end
	hen:dispatch('joystickadded!', j)
end

function love.joystickremoved(j)
	if not enable.event_joystick then return end
	hen:dispatch('joystickremoved!', j)
end

function love.joystickaxis(j, a, v)
	if not enable.event_joystick then return end
	hen:dispatch('joystickaxis!', j, a, v)
end

function love.joystickhat(j, h, d)
	if not enable.event_joystick then return end
	hen:dispatch('joystickhat!', j, h, d)
end

function love.joystickpressed(j, b)
	if not enable.event_joystick then return end
	hen:dispatch('joystickpressed!', j, b)
end

function love.joystickreleased(j, b)
	if not enable.event_joystick then return end
	hen:dispatch('joystickreleased!', j, b)
end

function love.gamepadaxis(j, a, v)
	if not enable.event_gamepad then return end
	hen:dispatch('gamepadaxis!', j, a, v)
end

function love.gamepadpressed(j, b)
	if not enable.event_gamepad then return end
	hen:dispatch('gamepadpressed!', j, b)
end

function love.gamepadreleased(j, b)
	if not enable.event_gamepad then return end
	hen:dispatch('gamepadreleased!', j, b)
end

-- ********************************************************************************
-- slightly adjusted love.run() - we don't call graphics.clear() in here, the screen does it later

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end
	local dt = 0
	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a, b, c, d, e, f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a, b, c, d, e, f)
			end
		end
		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end
		-- Call update and draw
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			if love.draw then love.draw() end
			love.graphics.present()
		end
		if love.timer then love.timer.sleep(0.001) end
	end
end

return hen
