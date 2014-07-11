-- BeeHelpers
-- Author: Nerijus
-- DateCreated: 10/3/2010 1:44:33 AM
-- Version 1.2
--------------------------------------------------------------
include("RandHelpers");

Dir = {}
Dir.UP_RIGHT = 0
Dir.RIGHT = 1
Dir.DOWN_RIGHT = 2
Dir.DOWN_LEFT = 3
Dir.LEFT = 4
Dir.UP_LEFT = 5

pg = {} -- planet generator helpers

pg.FH = 0.86602540

pg.newPlotInfo = function(initialTerrain)
	return {
		plotType = initialTerrain,
	};
end

pg.zeroRound = function(num) 
    if num >= 0 then return math.floor(num+.5) 
    else return math.ceil(num-.5) end
end

pg.setPlotTypes = function(plotInfoArray)
	local shallowWater = GameDefines.SHALLOW_WATER_TERRAIN;
	local deepWater = GameDefines.DEEP_WATER_TERRAIN;
	for i, plot in Plots() do
		local plotType = plotInfoArray[i + 1].plotType
		plot:SetPlotType(plotType, false, false);
		if plotType == PlotTypes.PLOT_OCEAN then
			plot:SetTerrainType(deepWater, false, false);
		elseif plotType == PlotTypes.PLOT_COAST then
			plot:SetTerrainType(shallowWater, false, false);
		end
	end
end

pg.translateFloatPointToTile = function(px, py)
	py = py * pg.FH * pg.FH
	local sh = 0.5 * pg.FH / 2
	local h3 = sh * 3
	local h4 = sh * 4
	local yindex = math.floor(py / h3)
	local yoffset = py - yindex
	if yindex % 2 == 0 then
		return pg.zeroRound(px), yindex
	else
		return pg.zeroRound(px - 0.5), yindex
	end
	return 0,0
end

pg.sizeInFloat = function(width, height)
	return width, height * pg.FH
end

--[[
My own MapInfo helper.
--]]
pg.MapInfo = function(width, height, isWrapX, isWrapY)
	local self
	self = {
		width = width,
		height = height,
		isWrapX = isWrapX,
		isWrapY = isWrapY,
		-- adjust out-of-bounds tile if it is wrapped in x direction
		fixWrapX = function(x)
			if isWrapX then
				x = x % width
			end
			return x
		end,
		-- adjust out-of-bounds tile if it is wrapped in y direction
		fixWrapY = function(y)
			if isWrapY then
				y = y % height
			end
			return y
		end,
		-- adjust both x and y of out-of-bounds tile
		fixWrap = function(x, y)
			return self.fixWrapX(x), self.fixWrapY(y)
		end,
		-- get x, y 1-based offset
		getOffset = function(x, y)
			x, y = self.fixWrap(x, y)
			return width * y + x + 1
		end,
		-- get x, y as 0-based indices from 1-based offset
		getXY = function(offset)
			offset = offset - 1
			return offset % width, math.floor(offset / width)
		end,
	}

	return self
end

--[[
Get relative tile in hex grid over some direction and number of steps.
direction: 0 up-right, 1 right, 2 down-right, 3 down-left, 4 left, 5 up-left
Result tile can be out of bounds.
--]]
pg.getRelativeTile = function(x, y, direction, steps)
	-- if no offset, return copy of the same location
	if steps == 0 then return x, y end
	if direction == Dir.RIGHT then
		return x + steps, y
	elseif direction == Dir.LEFT then
		return x - steps, y
	elseif direction == Dir.UP_LEFT then
		-- if steps is even, return half the steps
		if steps % 2 == 0 then return x - steps / 2, y + steps end
		-- return ceil if line is even, else return floor
		if y % 2 == 0 then 
			return x - math.ceil(steps / 2), y + steps
		else
			return x - math.floor(steps / 2), y + steps
		end
	elseif direction == Dir.UP_RIGHT then
		-- if steps is even, return half the steps
		if steps % 2 == 0 then return x + steps / 2, y + steps end
		-- return floor if line is even, else return ceil
		if y % 2 == 0 then 
			return x + math.floor(steps / 2), y + steps
		else
			return x + math.ceil(steps / 2), y + steps
		end
	elseif direction == Dir.DOWN_RIGHT then
		-- if steps is even, return half the steps
		if steps % 2 == 0 then return x + steps / 2, y - steps end
		-- return floor if line is even, else return ceil
		if y % 2 == 0 then 
			return x + math.floor(steps / 2), y - steps
		else
			return x + math.ceil(steps / 2), y - steps
		end
	elseif direction == Dir.DOWN_LEFT then
		-- if steps is even, return half the steps
		if steps % 2 == 0 then return x - steps / 2, y - steps end
		-- return ceil if line is even, else return floor
		if y % 2 == 0 then 
			return x - math.ceil(steps / 2), y - steps
		else
			return x - math.floor(steps / 2), y - steps
		end
	end
end

--[[
Checks if tile intersects with rectangle

x, y => tile to check
lx => leftX
ty => topY
rx => rightX
by => bottomY

wrapping assumed to be fixed before the call
produces bad results if rectangle is bigger than map size (obviously, because it's size is lost when wrapping is fixed)
--]]
pg.intersectsWithRectangle = function(x, y, lx, ty, rx, by)
	local insideX
	local insideY
	if lx > rx then
		insideX = x <= rx or x >= lx
	else
		insideX = x >= lx and x <= rx
	end
	if by > ty then
		insideY = y <= ty or y >= by
	else
		insideY = y >= by and y <= ty
	end
	return insideX and insideY
end

--[[
Checks if tile intersects with hex ring.

x, y => tile to check, should be unwrapped
cx, cy => center of the ring, can be wrapped
r => radius of the ring
fixWrap(x, y) -> x, y => function that fixes wrapping
--]]
pg.intersectsWithRing = function(x, y, cx, cy, r, mapInfo)
	local cxl = cx - r -- left of rectangle
	local cxr = cx + r -- right of rectangle
	local cyb = cy - r -- bottom
	local cyt = cy + r -- top
	local d = r * 2 + 1
	local uwcxl = mapInfo.fixWrapX(cxl) -- unwrapped left
	local uwcxr = mapInfo.fixWrapX(cxr) -- unwrapped right
	local uwcyb = mapInfo.fixWrapY(cyb) -- unwrapped bottom
	local uwcyt = mapInfo.fixWrapY(cyt) -- unwrapped top
	-- in case when ring is smaller than map size, we can check if it exists within rectangle to speed up computation a bit
	if d < mapInfo.width and d < mapInfo.height and not pg.intersectsWithRectangle(x, y, uwcxl, uwcyt, uwcxr, uwcyb) then
		return false
	else
		local uwcx = mapInfo.fixWrapX(cx) -- unwrapped cx
		local uwcy = mapInfo.fixWrapY(cy) -- unwrapped cy
		local isyeven = uwcy % 2 == 0
			
		if (x == uwcxl or x == uwcxr) and y == uwcy then -- check tiles on left and right
			return true
		end
		-- top and bottom
		if uwcyt == y or uwcyb == y then
			local skipl
			local skipr
			if r % 2 == 0 then
				skipl = math.floor(r / 2)
				skipr = math.ceil(r / 2)
			else
				skipl = math.ceil(r / 2)
				skipr = math.floor(r / 2)
			end
			if uwcyt == y then
				if uwcyt % 2 ~= 0 then
					for sx = cxl + skipr, cxr - skipl do
						if mapInfo.fixWrapX(sx) == x then
							return true
						end
					end
				else
					for sx = cxl + skipl, cxr - skipr do
						if mapInfo.fixWrapX(sx) == x then
							return true
						end
					end
				end
			end
			if uwcyb == y then
				if uwcyb % 2 ~= 0 then
					for sx = cxl + skipr, cxr - skipl do
						if mapInfo.fixWrapX(sx) == x then
							return true
						end
					end
				else
					for sx = cxl + skipl, cxr - skipr do
						if mapInfo.fixWrapX(sx) == x then
							return true
						end
					end
				end
			end
		end
		-- check ring sides
		for i = 1, r - 1 do
			local lx
			local rx
			local uwpy = mapInfo.fixWrapY(cy + i)
			local uwmy = mapInfo.fixWrapY(cy - i)
			if uwpy == y then
				if uwpy % 2 ~= 0 then
					lx = mapInfo.fixWrapX(cxl + math.floor(i / 2))
					rx = mapInfo.fixWrapX(cxr - math.ceil(i / 2))
				else
					lx = mapInfo.fixWrapX(cxl + math.ceil(i / 2))
					rx = mapInfo.fixWrapX(cxr - math.floor(i / 2))
				end
				if x == lx or x == rx then
					return true
				end
			end
			if uwmy == y then
				if uwmy % 2 ~= 0 then
					lx = mapInfo.fixWrapX(cxl + math.floor(i / 2))
					rx = mapInfo.fixWrapX(cxr - math.ceil(i / 2))
				else
					lx = mapInfo.fixWrapX(cxl + math.ceil(i / 2))
					rx = mapInfo.fixWrapX(cxr - math.floor(i / 2))
				end
				if x == lx or x == rx then
					return true
				end
			end
		end
		return false
	end
end

--[[
cx, cy must be unwrapped
--]]
pg.getRing = function(cx, cy, r, mapInfo)
	local result = {}

	local cxl = cx - r -- left of rectangle
	local cxr = cx + r -- right of rectangle
	local cyb = cy - r -- bottom
	local cyt = cy + r -- top
	local uwcxl = mapInfo.fixWrapX(cxl) -- unwrapped left +
	local uwcxr = mapInfo.fixWrapX(cxr) -- unwrapped right +
	local uwcyb = mapInfo.fixWrapY(cyb) -- unwrapped bottom +
	local uwcyt = mapInfo.fixWrapY(cyt) -- unwrapped top +
			
	-- left and right
	table.insert(result, { x = uwcxl, y = cy })
	table.insert(result, { x = uwcxr, y = cy })

	-- ring top and bottom
	local skipl
	local skipr
	if r % 2 == 0 then
		skipl = math.floor(r / 2)
		skipr = math.ceil(r / 2)
	else
		skipl = math.ceil(r / 2)
		skipr = math.floor(r / 2)
	end
	if uwcyt % 2 ~= 0 then
		for sx = cxl + skipr, cxr - skipl do
			table.insert(result, { x = mapInfo.fixWrapX(sx), y = uwcyt })
		end
	else
		for sx = cxl + skipl, cxr - skipr do
			table.insert(result, { x = mapInfo.fixWrapX(sx), y = uwcyt })
		end
	end
	if uwcyb % 2 ~= 0 then
		for sx = cxl + skipr, cxr - skipl do
			table.insert(result, { x = mapInfo.fixWrapX(sx), y = uwcyb })
		end
	else
		for sx = cxl + skipl, cxr - skipr do
			table.insert(result, { x = mapInfo.fixWrapX(sx), y = uwcyb })
		end
	end

	-- ring sides
	for i = 1, r - 1 do
		local lx
		local rx
		local uwpy = mapInfo.fixWrapY(cy + i)
		local uwmy = mapInfo.fixWrapY(cy - i)
		if uwpy % 2 ~= 0 then
			lx = mapInfo.fixWrapX(cxl + math.floor(i / 2))
			rx = mapInfo.fixWrapX(cxr - math.ceil(i / 2))
		else
			lx = mapInfo.fixWrapX(cxl + math.ceil(i / 2))
			rx = mapInfo.fixWrapX(cxr - math.floor(i / 2))
		end
		table.insert(result, { x = lx, y = uwpy })
		table.insert(result, { x = rx, y = uwpy })
		if uwmy % 2 ~= 0 then
			lx = mapInfo.fixWrapX(cxl + math.floor(i / 2))
			rx = mapInfo.fixWrapX(cxr - math.ceil(i / 2))
		else
			lx = mapInfo.fixWrapX(cxl + math.ceil(i / 2))
			rx = mapInfo.fixWrapX(cxr - math.floor(i / 2))
		end
		table.insert(result, { x = lx, y = uwmy })
		table.insert(result, { x = rx, y = uwmy })
	end

	return result
end

pg.getSimpleDistance = function(x1, y1, x2, y2, mapInfo)
	if y1 % 2 ~= 0 then -- adjust for uneven hex lines
		x1 = x1 + 0.5
	end
	if y2 % 2 ~= 0 then -- adjust for uneven hex lines
		x2 = x2 + 0.5
	end
	local dx
	local dy
	if mapInfo ~= nil and mapInfo.isWrapX then
		local wrappeddx
		if x1 < x2 then
			wrappeddx = math.abs(x2 - mapInfo.width)
			dx = x2 - x1
		else
			wrappeddx = math.abs(x1 - mapInfo.width)
			dx = x1 - x2
		end
		if wrappeddx < dx then
			dx = wrappeddx
		end
	else
		dx = math.abs(x1 - x2)
	end
	if mapInfo ~= nil and mapInfo.isWrapY then
		local wrappeddy
		if y1 < y2 then
			wrappeddy = math.abs(y2 - mapInfo.height)
			dy = y2 - y1
		else
			wrappeddy = math.abs(y1 - mapInfo.height)
			dy = y1 - y2
		end
		if wrappeddy < dy then
			dy = wrappeddy
		end
	else
		dy = math.abs(y1 - y2)
	end
	return math.sqrt(dx ^ 2 + dy ^ 2)
end

--[[
Get random path between two points

deviation changes how random path can be. When deviation == 0, path is mostly straight, when deviation == 1, path is the most randomized
--]]
pg.getRandomPath = function(x1, y1, x2, y2, deviation, mapInfo)
	local result1 = { { x = x1, y = y1 } }; local count1 = 1
	local result2 = { { x = x2, y = y2 } }; local count2 = 1

	local getRandomTile = function(x, y, tx, ty)
		local randomTiles = dice.WeightedItems()
		local ring = pg.getRing(x, y, 1, mapInfo)
		local maxDistance = nil
		local minDistance = nil
		local distances = {}
		for i, item in pairs(ring) do
			if not (item.x == x and item.y == y) then
				local distance = pg.getSimpleDistance(tx, ty, item.x, item.y, nil)
				if maxDistance == nil or distance > maxDistance then
					maxDistance = distance
				end
				if minDistance == nil or distance < minDistance then
					minDistance = distance
				end
				distances[i] = distance
			end
		end
		local distanceVariation = maxDistance - minDistance
		for i, distance in pairs(distances) do
			local itemRelevance = 1 - (distance - minDistance) / distanceVariation + 0.01
			if itemRelevance > 0.9 - deviation then
				randomTiles.add(itemRelevance, ring[i])
			end
		end
		local rt = randomTiles.get()
		return rt.x, rt.y
	end

	local findMatch = function(x, y, result) -- find 1-based index of matching x, y in result, or nil
		for i, item in pairs(result) do
			if item.x == x and item.y == y then
				return i
			end
		end
		return nil
	end

	local constructResult = function(matchIndex1, result1, result2) -- add result from result2 as-it-is, but limit result1 at match index
		local result = {}
		for _, v in ipairs(result2) do
			table.insert(result, v)
		end
		for i = matchIndex1, 1, -1 do
			table.insert(result, result1[i])
		end
		return result
	end

	for searchIndex = 0, mapInfo.width * mapInfo.height do -- if it does not return anything even if it added more tiles than exist on map, return nil
		local nx1, ny1 = getRandomTile(x1, y1, x2, y2)
		local nx2, ny2 = getRandomTile(x2, y2, x1, y1)
		table.insert(result1, { x = nx1, y = ny1 }); count1 = count1 + 1
		table.insert(result2, { x = nx2, y = ny2 }); count2 = count2 + 1
		local matchIndex = findMatch(nx2, ny2, result1)
		if matchIndex ~= nil then
			return constructResult(matchIndex, result1, result2)
		end
		local matchIndex = findMatch(nx1, ny1, result2)
		if matchIndex ~= nil then
			return constructResult(matchIndex, result2, result1)
		end
		x1 = nx1; y1 = ny1; x2 = nx2; y2 = ny2
	end

	print("-- Warning, path between tiles was not found! --")

	return nil
end

--[[
Checks if tile intersects with hex area.

x, y => tile to check, should be unwrapped
cx, cy => center of the ring, can be wrapped
r => radius of the ring
fixWrap(x, y) -> x, y => function that fixes wrapping

!! not finished !!
--]]
pg.intersectsWithHex = function(x, y, cx, cy, r, mapInfo)
	local ringLX = mapInfo.fixWrapX(cx - r)
	local ringRX = mapInfo.fixWrapX(cx + r)
	local ringBY = mapInfo.fixWrapY(cy - r)
	local ringTY = mapInfo.fixWrapY(cy + r)
	if not pg.intersectsWithRectangle(x, y, ringLX, ringTY, ringRX, ringBY, mapInfo) then
		return false
	else
		return true -- todo
	end
end

--[[
Sprays random tiles evenly over wrapped world view

wrappedView must have width, height, tileIntersectsWithAllTiles()
--]]
pg.sprayTiles = function(wrappedView, minDistance, attemptsToFail)
	local usedOffsets = {}
	local attempts = 0
	local maxTimes = 100
	local times = 0
	while attempts < attemptsToFail and times < maxTimes do
		local offset = Map.Rand(wrappedView.mapInfo.width * wrappedView.mapInfo.height, "BeeHelpers: Spray random tile") + 1
		local rx, ry = wrappedView.mapInfo.getXY(offset)
		local offsetUsed = usedOffsets[offset] ~= nil;
		if offsetUsed or wrappedView.tilesIntersectsWithHexArea(usedOffsets, rx, ry, minDistance) then
			attempts = attempts + 1
		else
			usedOffsets[offset] = true
			attempts = 0
		end
	end
	return usedOffsets
end

pg.bee = {
	--[[
	Class provides wrapped 2D view of 2D array passed and returned as 1D array
	--]]
	WrappedView = function(mapInfo, initialItemFun)
		local arraySize = mapInfo.width * mapInfo.height
		local array = {}

		if initialItemFun == nil then 
			array = table.fill(nil, arraySize)
		else
			for i = 1, arraySize do
				array[i] = initialItemFun(i)
			end
		end

		return {
			-- returns info about array
			array = array,
			arraySize = arraySize,
			mapInfo = mapInfo,

			-- returns info about array over wrap filter
			get = function(x, y)
				return array[mapInfo.getOffset(x, y)]
			end,
			at = function(offset)
				return array[offset]
			end,
			set = function(x, y, value)
				array[mapInfo.getOffset(x, y)] = value
			end,
			tilesIntersectWithHexArea = function(tilesOffset, ax, ay, distance)
				--for ringNumber = 1, distance do
					for offset, _ in pairs(tilesOffset) do
						local tx, ty = mapInfo.getXY(offset)
						--print("-- offset "..offset.." as xy is "..tx..", "..ty)
						if pg.intersectsWithRing(tx, ty, ax, ay, distance, mapInfo) then
							return true
						end
					end
				--end
				return false
			end,
			tilesOf = function(tileFunction)
				local result = {}
				for i = 1, arraySize do
					local plot = array[i]
					if tileFunction(plot) then
						result[i] = plot
					end
				end
				return result
			end,
		}
	end,
	--[[
	Class provides rotated view of the hex grid from the POV of a "bee", which doesn't know nor care how it is rotated
	--]]
	BeeView = function(model, mx, my, direction)
		local x = mx; if x == nil then x = 0 end
		local y = my; if y == nil then y = 0 end
		local direction = direction; if direction == nil then direction = 0 end
			
		return {
			-- returns info about array over rotation filter
			rotate = function(times)
				
			end,
			get = function(ox, oy)
					
			end,
		}
	end,
	--[[
	Class to spit out random pattern of tiles with specified settings
	--]]
	BeeBuilder = function(beeViews)
		return {
			--[[
			Grows a tile at specified beeViews
			--]]
			grow = function()
				return false
			end,

		}
	end,
}