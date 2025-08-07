
-- we require the ability to copy from a table into a table, recusrively
local function copyInto(from, to)
	for i, v in ipairs(from) do
		if type(v) == 'table' then
			to[i] = {}
			copyInto(v, to[i])
		else
			to[i] = v
		end
	end
	for k, v in pairs(from) do
		if type(v) == 'table' then
			to[k] = {}
			copyInto(v, to[k])
		else
			to[k] = v
		end
	end
end

-- read the conf from .json and give it to lua
function love.conf(t)
	local json = require '❤️.json'
	henConfig = json.decode(love.filesystem.read('conf.json'))
	copyInto(henConfig, t)
end