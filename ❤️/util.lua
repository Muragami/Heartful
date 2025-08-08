-- ********************************************************************************
-- utility functions

local inspect = require '❤️.inspect'
-- luajit string buffers
local buffer = require 'string.buffer'

-- luajit table extensions
local tclear = require 'table.clear'
local tnew = require 'table.new'

-- local functions since they are called a lot
local tinsert = table.insert
local tremove = table.remove

-- always return a subtable of a table, creating as needed
local function subtable(t, name)
	if t[name] then return t[name] end
	t[name] = {}
	return t[name]
end

-- recursive table copy 'into'
local function copyInto(from, to)
	for k, v in pairs(from) do
		if type(v) == 'table' then
			if type(to[k]) ~= 'table' then
				to[k] = {}
			end
			copyInto(v, to[k])
		else
			to[k] = v
		end
	end
end

-- recursive table copy 'new'
local function makeCopy(from)
	local to = {}
	for k, v in pairs(from) do
		if type(v) == 'table' then
			to[k] = makeCopy(v)
		else
			to[k] = v
		end
	end
	return to
end

-- trim a leading '~' root specifier from a path
local function trimPath(path)
	if path:sub(1, 1) == '~' then return path:sub(2) end
	return path
end

-- use a luajit string buffer to build a string with \ and / replaced with .
local function dir2dot(v)
	local b = buffer.new(#v)
	for i = 1, #v, 1 do
		if v:sub(i, i) == '/' or v:sub(i, i) == '\\' then
			if i ~= 1 then b:put('.') end
		else
			b:put(v:sub(i, i))
		end
	end
	return b:tostring()
end

-- combine group and name
local function combine(grp, name, sep)
	if not sep then sep = ':' end
	return (grp or '?') .. sep .. (name or '?')
end

-- split a string by a token sep
local function split(inputstr, sep)
	if not sep then sep = "%s" end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		tinsert(t, str)
	end
	return t
end

-- breakup a name given 'grp:name' as needed
local function breakup(grp, name)
	if not grp then
		grp, name = unpack(split(name, ':'))
	end
	return grp, name
end

-- some default values for configuration
local defaults = {
	box = {
		x = 0,
		y = 0,
		z = 0,
		width = 0,
		height = 0,
		sx = 1,
		sy = 1,
		r = 0,
		rox = 0,
		roy = 0
	},
	layer = false,
	screen = false,
	dead = false,
	lifetime = false,
	classname = "",
	id = -1,
}

-- remove an index in an unsorted array collection
local function remove(t, id)
	if #t > id then
		t[id] = t[#t] -- move the last one into the slot
	end
	tremove(t)
end

-- build an entry into the super table with all further up super
-- entries compiled down into it, like 'layer' contains 'entity'
-- and 'layer' baked in
local superstable = {}
local function buildSupers(prototable, supername, to)
	if superstable[supername] then
		copyInto(superstable[supername], to)
	else
		local t = {}
		local compiled = {}
		local pt = prototable[supername] or error('buildSupers() no prototype named: ' .. supername)
		tinsert(t, pt)
		while pt.super do
			tinsert(t, prototable[pt.super])
			pt = prototable[pt.super]
		end
		for i = #t, 1, -1 do
			copyInto(t[i], compiled)
		end
		superstable[supername] = compiled
		copyInto(compiled, to)
	end
end

-- an empty function to work as a placeholder
local function noCall(obj) end

-- utility blank table, so we don't have to create empty ones on the fly
local blank = {}

-- utility null object
local null = { name = 'null', group = '*' }

-- insertion sort, taken from batteries (https://github.com/1bardesign/batteries/blob/master/sort.lua),
-- in turn from Dirk Laurie and Steve Fisher.
local function insertionSort(array, first, last, less)
	for i = first + 1, last do
		local k = first
		local v = array[i]
		for j = i, first + 1, -1 do
			if less(v, array[j - 1]) then
				array[j] = array[j - 1]
			else
				k = j
				break
			end
		end
		array[k] = v
	end
end

-- Left run is A[iLeft : iRight-1].
-- Right run is A[iRight : iEnd-1].
local function merge(A, iLeft, iRight, iEnd, B, lesseq)
	local i, j = iLeft, iRight
	--print('merge: ' .. tostring(iLeft) .. '-' .. tostring(iEnd) .. '/' .. tostring(iRight))
	-- While there are elements in the left or right runs...
	for k = iLeft, iEnd + 1, 1 do
		-- If left run head exists and is <= existing right run head.
		if i < iRight and (j >= iEnd or lesseq(A[i], A[j])) then
			B[k] = A[i]
			i = i + 1
		else
			B[k] = A[j]
			j = j + 1
		end
	end
end

-- array A[] has the items to sort; array B[] is a work array
local function mergeSort(A, B, lesseq)
	-- Each 1-element run in A is already "sorted".
	-- Make successively longer sorted runs of length 2, 4, 8, 16... until the whole array is sorted.
	local n = #A + 1
	local width = 1
	local temp
	local swap = false
	while width < n do
		-- Array A is full of runs of length width.
		local i = 1
		--print('width = ' .. tostring(width))
		while i <= n do
			-- Merge two runs: A[i:i+width-1] and A[i+width:i+2*width-1] to B[]
			-- or copy A[i:n-1] to B[] ( if (i+width >= n) )
			merge(A, i, math.min(i + width, n), math.min(i + 2 * width, n), B, lesseq);
			i = i + 2 * width
		end
		-- Now work array B is full of runs of length 2*width.
		-- Copy array B to array A for the next iteration.
		-- A more efficient implementation would swap the roles of A and B.
		--print('array = ' .. inspect(B))
		temp = A
		A = B
		B = temp
		swap = not swap
		width = width * 2
	end
	if swap then
		--print("swapped")
		for i, v in ipairs(A) do
			B[i] = v
		end
	end
end

-- drawing options supported by the engine
local drawtype = {
	none = 1,
	quad = 2,
	line = 3,
	rect = 4,
	ellipse = 5,
	arc = 6,
	polygon = 7,
	points = 8,
	supershape = 9
}

-- return our utilities
return {
	subtable = subtable,
	copyInto = copyInto,
	makeCopy = makeCopy,
	trimPath = trimPath,
	dir2dot = dir2dot,
	combine = combine,
	split = split,
	breakup = breakup,
	remove = remove,
	defaults = defaults,
	buildSupers = buildSupers,
	noCall = noCall,
	blank = blank,
	null = null,
	insertionSort = insertionSort,
	mergeSort = mergeSort,
	drawtype = drawtype,
}
