local LIP = {
	_VERSION      = 'LIP ?',
	_DESCRIPTION  = 'INI file handling library',
	_URL          = 'https://github.com/Dynodzzo/Lua_INI_Parser',
	_COPYRIGHT    = 'Copyright (c) 2012 Dynodzzo',
	_NOTES        = [[Modified by muragami (Jason A. Petrasko) 2025 to support encode/decode
  									string INI data, some code cleanup ]],
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

local function strlines(s)
	return s:gmatch("(.-)\n")
end

--- Returns a table containing all the data from the source INI format string.
--@param str a string of INI data source
--@return The table containing all data from the INI file. [table]
function LIP.decode(str)
	assert(type(str) == 'string', 'Parameter "str" must be a string.')
	local data = {}
	local section
	if str:sub(-1) ~= "\n" then str = str .. "\n" end
	for line in strlines(str) do
		local tempSection = line:match('^%[([^%[%]]+)%]$')
		if (tempSection) then
			section = tonumber(tempSection) and tonumber(tempSection) or tempSection
			data[section] = data[section] or {}
		end
		local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$')
		if (param and value ~= nil) then
			if (tonumber(value)) then
				value = tonumber(value)
			elseif (value == 'true') then
				value = true
			elseif (value == 'false') then
				value = false
			end
			if (tonumber(param)) then
				param = tonumber(param)
			end
			if not data[section] then data[section] = {} end
			data[section][param] = value
		end
	end
	return data
end

--- Saves all the data from a table to an INI encoded string.
--@param data The table containing all the data to store. [table]
--@return The string of INI format for this table. [string]
function LIP.encode(data)
	assert(type(data) == 'table', 'Parameter "data" must be a table.')
	local contents = ''
	for section, param in pairs(data) do
		contents = contents .. ('[%s]\n'):format(section)
		for key, value in pairs(param) do
			contents = contents .. ('%s=%s\n'):format(key, tostring(value))
		end
		contents = contents .. '\n'
	end
	return contents
end

return LIP
