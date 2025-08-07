--[[
MIT License

Copyright (c) 2021, 2025 JasonP, muragami, muragami@wishray.com

An implementation of MAXRECTS in Lua

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

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

local _INVALID = {}

local function _clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[_clone(orig_key)] = _clone(orig_value)
        end
        setmetatable(copy, _clone(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function _copyrect(rect)
	return {
		rect[1], rect[2], -- 1:x and 2:y
		rect[3], rect[4], -- 3:w and 4:h
		rect[5], rect[6], -- 5:data and 6:flipped
	}
end

local function _FindPositionForNewNodeBSSF(self, width, height)
	local bestNode = { 0, 0, 0, 0, false, false }

	local bestShortSideFit, bestLongSideFit = math.huge, math.huge

	local rectToProcess = #self.freeRectangles
	for i = 1, rectToProcess, 1 do
		local rect = self.freeRectangles[i]
		-- Try to place the rectangle in upright (non-flipped) orientation.
		if rect[3] >= width and rect[4] >= height then
			local leftoverHoriz = math.abs(rect[3] - width)
			local leftoverVert = math.abs(rect[4] - height)
			local shortSideFit = math.min(leftoverHoriz, leftoverVert)
			local longSideFit = math.max(leftoverHoriz, leftoverVert)

			if shortSideFit < bestShortSideFit or (shortSideFit == bestShortSideFit and longSideFit < bestLongSideFit) then
				bestNode[1] = rect[1]
				bestNode[2] = rect[2]
				bestNode[3] = width
				bestNode[4] = height
				bestShortSideFit = shortSideFit
				bestLongSideFit = longSideFit
			end
		end

		if self.bFlip and rect[3] >= height and rect[4] >= width then
			local flippedLeftoverHoriz = math.abs(rect[3] - height)
			local flippedLeftoverVert = math.abs(rect[4] - width)
			local flippedShortSideFit = math.min(flippedLeftoverHoriz, flippedLeftoverVert)
			local flippedLongSideFit = math.max(flippedLeftoverHoriz, flippedLeftoverVert)

			if flippedShortSideFit < bestShortSideFit or (flippedShortSideFit == bestShortSideFit and flippedLongSideFit < bestLongSideFit) then
				bestNode[1] = rect[1]
				bestNode[2] = rect[2]
				bestNode[3] = width
				bestNode[4] = height
				bestShortSideFit = flippedShortSideFit
				bestLongSideFit = flippedLongSideFit
        bestNode[6] = true
			end
		end
	end
	return bestNode
end

local function _FindPositionForNewNodeBLSF(self, width, height)
	local bestNode = { 0, 0, 0, 0, false, false }

  local bestShortSideFit, bestLongSideFit = math.huge, math.huge

	local rectToProcess = #self.freeRectangles
	for i = 1, rectToProcess, 1 do
		local frect = self.freeRectangles[i]
		-- Try to place the rectangle in upright (non-flipped) orientation.
		if frect[3] >= width and frect[4] >= height then
			local leftoverHoriz = math.abs(frect[3] - width)
			local leftoverVert = math.abs(frect[4] - height)
			local shortSideFit = math.min(leftoverHoriz, leftoverVert)
			local longSideFit = math.max(leftoverHoriz, leftoverVert)

			if longSideFit < bestLongSideFit or (longSideFit == bestLongSideFit and shortSideFit < bestShortSideFit) then
				bestNode[1] = frect[1]
				bestNode[2] = frect[2]
				bestNode[3] = width
				bestNode[4] = height
				bestShortSideFit = shortSideFit
				bestLongSideFit = longSideFit
			end
		end

		if self.bFlip and frect[3] >= height and frect[4] >= width then
			local leftoverHoriz = math.abs(frect[3] - height)
			local leftoverVert = math.abs(frect[4] - width)
			local shortSideFit = math.min(leftoverHoriz, leftoverVert)
			local longSideFit = math.max(leftoverHoriz, leftoverVert)

			if longSideFit < bestLongSideFit or (longSideFit == bestLongSideFit and shortSideFit < bestShortSideFit) then
				bestNode[1] = frect[1]
				bestNode[2] = frect[2]
				bestNode[3] = height
				bestNode[4] = width
				bestShortSideFit = shortSideFit
				bestLongSideFit = longSideFit
        bestNode[6] = true
			end
		end
	end
	return bestNode
end

local function _FindPositionForNewNodeBAF(self, width, height)
	local bestNode = { 0, 0, 0, 0, false, false }

  local bestAreaFit, bestShortSideFit = math.huge, math.huge

	local rectToProcess = #self.freeRectangles
	for i = 1, rectToProcess, 1 do
		local frect = self.freeRectangles[i]
		local areaFit = frect[3] * frect[4] - width * height

		-- Try to place the rectangle in upright (non-flipped) orientation.
		if frect[3] >= width and frect[4] >= height then
			local leftoverHoriz = math.abs(frect[3] - width)
			local leftoverVert = math.abs(frect[4] - height)
			local shortSideFit = math.min(leftoverHoriz, leftoverVert)

			if areaFit < bestAreaFit or (areaFit == bestAreaFit and shortSideFit < bestShortSideFit) then
				bestNode[1] = frect[1]
				bestNode[2] = frect[2]
				bestNode[3] = width
				bestNode[4] = height
				bestAreaFit = areaFit
				bestShortSideFit = shortSideFit
			end
		end

		if self.bFlip and frect[3] >= height and frect[4] >= width then
			local leftoverHoriz = math.abs(frect[3] - height)
			local leftoverVert = math.abs(frect[4] - width)
			local shortSideFit = math.min(leftoverHoriz, leftoverVert)

			if areaFit < bestAreaFit or (areaFit == bestAreaFit and shortSideFit < bestShortSideFit) then
				bestNode[1] = frect[1]
				bestNode[2] = frect[2]
				bestNode[3] = height
				bestNode[4] = width
				bestAreaFit = areaFit
				bestShortSideFit = shortSideFit
        bestNode[6] = true
			end
		end
	end
	return bestNode
end

local function _CommonIntervalLength(i1start, i1end, i2start, i2end)
	if i1end < i2start or i2end < i1start then return 0 end
	return math.min(i1end, i2end) - math.max(i1start, i2start)
end

function _ContactPointScoreNode(self, x, y, width, height)
	local score = 0

	if x == 0 or (x + width == self.bWidth) then score = score + height end
	if y == 0 or (y + height == self.bHeight) then score = score + width end

	local rectToProcess = #self.usedRectangles
	for i = 1, rectToProcess, 1 do
		local rect = self.usedRectangles[i]
		if (rect[1] == x + width) or (rect[1] + rect[3] == x) then
			score = score + _CommonIntervalLength(rect[2], rect[2] + rect[4], y, y + height)
		end
		if (rect[2] == y + height) or (rect[2] + rect[4] == y) then
			score = score + _CommonIntervalLength(rect[1], rect[1] + rect[3], x, x + width)
		end
	end
	return score
end

local function _FindPositionForNewNodeCP(self, width, height)
	local bestNode = { 0, 0, 0, 0, false, false }

  local bestContactScore = -1

	local rectToProcess = #self.freeRectangles
	for i = 1, rectToProcess, 1 do
		local frect = self.freeRectangles[i]
		-- Try to place the rectangle in upright (non-flipped) orientation.
		if frect[3] >= width and frect[4] >= height then
			local score = _ContactPointScoreNode(self, frect[1], frect[2], width, height)
			if score > bestContactScore then
				bestNode[1] = frect[1]
				bestNode[2] = frect[2]
				bestNode[3] = width
				bestNode[4] = height
				bestContactScore = score
			end
		end
		if self.bFlip and frect.width >= height and frect.height >= width then
			local score = _ContactPointScoreNode(frect[1], frect[2], height, width)
			if score > bestContactScore then
				bestNode[1] = frect[1]
				bestNode[2] = frect[2]
				bestNode[3] = height
				bestNode[4] = width
				bestContactScore = score
			end
		end
	end
	return bestNode
end

-- table for our various heuristic functions
local FreeRectChoiceHeuristic = {
		BestShortSideFit = _FindPositionForNewNodeBSSF,
			-- -BSSF: Positions the rectangle against the short side of a free rectangle into which it fits the best.
		BestLongSideFit = _FindPositionForNewNodeBLSF,
			-- -BLSF: Positions the rectangle against the long side of a free rectangle into which it fits the best.
		BestAreaFit = _FindPositionForNewNodeBAF,
			-- -BAF: Positions the rectangle into the smallest free rect into which it fits.
		ContactPointRule =  _FindPositionForNewNodeCP }
			-- -CP: Choosest the placement where the rectangle touches other rects as much as possible.

-- table for names for the heuristics
local FreeRectChoiceHeuristicName = {
		[_FindPositionForNewNodeBSSF] = "BestShortSideFit",
		[_FindPositionForNewNodeBLSF] = "BestLongSideFit",
		[_FindPositionForNewNodeBAF] = "BestAreaFit",
		[_FindPositionForNewNodeCP] = "ContactPointRule" }

local function _IsContainedIn(ra, rb)
	return ra[1] >= rb[1] and ra[2] >= rb[2]
				and ra[1] + ra[3] <= rb[1] + rb[3]
				and ra[2] + ra[4] <= rb[2] + rb[4]
end

MaxRects = { bWidth = 0, bWeight = 0, bFlip = false,
	freeRectangles = {}, usedRectangles = {},
 	algorithm = _FindPositionForNewNodeBSSF, scores = {} }

function MaxRects:insert(width, height, data)
	local newNode
	newNode = self:algorithm(width, height)
	if newNode[4] == 0 then return false end
	local rectToProcess = #self.freeRectangles
	for i = 1, rectToProcess, 1 do
		if self.freeRectangles[i] ~= _INVALID then
			if self:splitFreeNode(self.freeRectangles[i], newNode) then
				-- remove this later!
				self.freeRectangles[i] = _INVALID
			end
		end
	end
	self:pruneFreeList()
	-- attach data if we have it
	if data then newNode[5] = data end
	table.insert(self.usedRectangles, newNode)
	return true
end

function MaxRects:insertRect(rect)
  local newNode
	newNode = self:algorithm(rect[3], rect[4])
	if newNode[4] == 0 then return false end
	local rectToProcess = #self.freeRectangles
	for i=1,rectToProcess,1 do
		if self.freeRectangles[i] ~= _INVALID then
			if self:splitFreeNode(self.freeRectangles[i], newNode) then
				-- remove this later!
				self.freeRectangles[i] = _INVALID
			end
		end
	end
	self:pruneFreeList()
	-- attach data if we have it
  newNode[5] = rect[5]
	table.insert(self.usedRectangles,newNode)
	return true
end

function MaxRects:occupancy()
	local usedSurfaceArea = 0
	local count = #self.usedRectangles
	for i=1,count,1 do
		local rect = self.usedRectangles[i]
		usedSurfaceArea = usedSurfaceArea + rect[3] * rect[4]
	end
	return usedSurfaceArea / (self.bWidth * self.bHeight)
end

function MaxRects:algorithmName()
	return FreeRectChoiceHeuristicName[self.algorithm]
end

-- iterate over all contained rects with a function or a function needing self
function MaxRects:iterate(func, otherself)
	local count = #self.usedRectangles
	if otherself then
		for i=1,count,1 do
			func(otherself,self.usedRectangles[i])
		end
	else
		for i=1,count,1 do
			func(self.usedRectangles[i])
		end
	end
end

function MaxRects:init(width, height, canflip)
	self.bFlip = canflip or self.bFlip
	self.bWidth = width or self.bWidth
	self.bHeight = height or self.bHeight
	self.freeRectangles = {}
	self.usedRectangles = {}
	table.insert(self.freeRectangles, { 0, 0, width, height })
end

function MaxRects:reset(width, height, canflip) self:init(width, height, canflip) end

function MaxRects:setAlgorithm(algo)
	if FreeRectChoiceHeuristic[algo] then
		self.algorithm = FreeRectChoiceHeuristic[algo]
	else error("MaxRects:setAlgorithm() got bad algo: " .. algo) end
end

-- inverted so that we sort descending
local function _IsRectAreaLarger(a,b)
  return (a[3] * a[4]) > (b[3] * b[4])
end

-- inverted so that we sort descending
local function _IsLongSideLonger(a,b)
  return math.max(a[3],a[4]) > math.max(b[3],b[4])
end

-- inverted so that we sort descending
local function _IsShortSideLonger(a,b)
  return math.min(a[3],a[4]) > math.min(b[3],b[4])
end

function MaxRects:insertCollection(collect, sort)
  local docoll = collect
  local all = true
  if sort == 'SortArea' then
    table.sort(docoll, _IsRectAreaLarger)
  elseif sort == 'SortLongSide' then
    table.sort(docoll, _IsLongSideLonger)
  elseif sort == 'SortShortSide' then
    table.sort(docoll, _IsShortSideLonger)
  else
    if sort then error("MaxRects:insertCollection() bad sort method: " .. sort) end
  end
  local totalRects = #docoll
  local added = 0
  for i=1, totalRects, 1 do
    -- add the rect, or uh quit out
    if self:insertRect(docoll[i]) then added = added + 1
      else all = false break end
  end
  -- return if we added all, and the count of how many
  return all, added
end

function MaxRects:splitFreeNode(freeNode, usedNode)
	-- Test with SAT if the rectangles even intersect.
	if usedNode[1] >= freeNode[1] + freeNode[3] or usedNode[1] + usedNode[3] <= freeNode[1] or
		usedNode[2] >= freeNode[2] + freeNode[4] or usedNode[2] + usedNode[4] <= freeNode[2] then
		return false
	end

	if usedNode[1] < freeNode[1] + freeNode[3] and usedNode[1] + usedNode[3] > freeNode[1] then
		-- New node at the top side of the used node.
		if usedNode[2] > freeNode[2] and usedNode[2] < freeNode[2] + freeNode[4] then
			local newNode = _copyrect(freeNode)	-- fast rect array copy
			newNode[4] = usedNode[2] - newNode[2]
			table.insert(self.freeRectangles,newNode)
		end

		-- New node at the bottom side of the used node.
		if usedNode[2] + usedNode[4] < freeNode[2] + freeNode[4] then
			local newNode = _copyrect(freeNode)	-- fast rect array copy
			newNode[2] = usedNode[2] + usedNode[4]
			newNode[4] = freeNode[2] + freeNode[4] - (usedNode[2] + usedNode[4])
			table.insert(self.freeRectangles,newNode)
		end
	end

	if usedNode[2] < freeNode[2] + freeNode[4] and usedNode[2] + usedNode[4] > freeNode[2] then
		-- New node at the left side of the used node.
		if usedNode[1] > freeNode[1] and usedNode[1] < freeNode[1] + freeNode[3] then
			local newNode = _copyrect(freeNode)	-- fast rect array copy
			newNode[3] = usedNode[1] - newNode[1]
			table.insert(self.freeRectangles,newNode)
		end

		-- New node at the right side of the used node.
		if usedNode[1] + usedNode[3] < freeNode[1] + freeNode[3] then
			local newNode = _copyrect(freeNode)	-- fast rect array copy
			newNode[1] = usedNode[1] + usedNode[3]
			newNode[3] = freeNode[1] + freeNode[3] - (usedNode[1] + usedNode[3])
			table.insert(self.freeRectangles,newNode)
		end
	end

	return true
end

-- Go through each pair and remove any rectangle that is redundant.
function MaxRects:pruneFreeList()
	local rectToProcess = #self.freeRectangles
	for i=1,rectToProcess,1 do
		local recta = self.freeRectangles[i]
		if recta ~= _INVALID then
			for j=i+1,rectToProcess,1 do
				local rectb = self.freeRectangles[j]
				if rectb ~= _INVALID then
					if _IsContainedIn(recta, rectb) then
						self.freeRectangles[i] = _INVALID
						--i
					elseif _IsContainedIn(rectb, recta) then
						self.freeRectangles[j] = _INVALID
						--j
					end
				end
			end
		end
	end
	self:compact()
end

-- remove all the empty entries, backwards to prevent having to shift them about if possible
function MaxRects:compact()
	local rectToProcess = #self.freeRectangles
	for i=rectToProcess,1,-1 do
		if self.freeRectangles[i] == _INVALID then
			table.remove(self.freeRectangles,i)
		end
	end
end

--
-- Finalize things
--

local safeMaxRects = _clone(MaxRects)

function MaxRects.new(width, height, canflip)
	local ret = _clone(safeMaxRects)
	ret:init(width, height, canflip)
	return ret
end

function MaxRects.copy(rect)
  return { rect[1], rect[2], rect[3], rect[4], data = rect[5], flipped = rect[6] }
end

-- return the table in case a user expects that with = require 'maxrects'
return MaxRects
