-- CircleOfWar
-- Author: Nerijus
-- DateCreated: 10/5/2010 9:54:58 PM
--------------------------------------------------------------
include("MapGenerator");
include("BeeHelpers");
include("FeatureGenerator");
include("TerrainGenerator");

function GetMapScriptInfo()
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	return {
		Name = "TXT_KEY_COW_MAP_FAIR",
		Description = "TXT_KEY_COW_MAP_FAIR_HELP",
		SupportsMultiplayer = true,
		IconIndex = 1,
		CustomOptions = {temperature, rainfall, resources,
			{
				Name = "TXT_KEY_COW_MAP_OPTION_CIRCLE_TYPE",
				Values = {
					"TXT_KEY_COW_MAP_OPTION_MANY_SEAS",
					"TXT_KEY_COW_MAP_OPTION_LESS_SEAS",
					"TXT_KEY_COW_MAP_OPTION_RANDOM",
				},
				DefaultValue = 1,
				SortPriority = 1,
			},
		},
	}
end

function GetMapInitData(worldSize)
	-- This function can reset map grid sizes or world wrap settings.

	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {20, 20},
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {40, 24},
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {52, 32},
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {64, 40},
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {84, 52},
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {104, 64}
		}
	local grid_size = worldsizes[worldSize];
	--
	local world = GameInfo.Worlds[worldSize];
	if(world ~= nil) then
	return {
		Width = grid_size[1],
		Height = grid_size[2],
		WrapX = true,
		WrapY = true,
	};      
     end
end

local mapInfo

function GeneratePlotTypes()
	-- This is a basic, empty shell. All map scripts should replace this function with their own.
	print("Generating Plot Types (CircleOfWar.Lua)");
	
	local gridWidth, gridHeight = Map.GetGridSize()

	mapInfo = pg.MapInfo(gridWidth, gridHeight, Map:IsWrapX(), Map:IsWrapY())

	local wrappedWorld = pg.bee.WrappedView(mapInfo, function(i)
		return pg.newPlotInfo(PlotTypes.PLOT_OCEAN)
	end)

	local maxSize = 128*80
	local minSize = 20*20
	local thisSize = gridWidth * gridHeight
	local relation = ((thisSize - minSize) / (maxSize - minSize)) * math.pi / 2

	local getRing = function(cx, cy, rw, rh)
		local ringParts = {}

		local r = (rw + rh) / 2
		local perimeter = 2 * math.pi * r
		local pieceP = mapInfo.height / 4
		local pieceCount = math.floor(perimeter / pieceP)
		local pieceAngle = pieceP / r
		for i = 0, pieceCount do
			local totalAngle = i * pieceAngle
			local x = math.cos(totalAngle) * rw + cx
			local y = math.sin(totalAngle) * rh + cy
			local ix, iy = pg.translateFloatPointToTile(x, y)
			local plot = wrappedWorld.get(ix, iy)
			if plot ~= nil then
				table.insert(ringParts, { offset = wrappedWorld.mapInfo.getOffset(ix, iy), plot = plot })
			end
		end

		return ringParts
	end

	local fw, fh = pg.sizeInFloat(gridWidth, gridHeight)
	
	local randomPlotType = dice.WeightedItems({8,PlotTypes.PLOT_LAND}, {3,PlotTypes.PLOT_HILLS})

	local getRandomRing = function(deviation, rw, rh)
		local result = {}

		local ringTiles = getRing(fw / 2, math.floor(fh / 2 + 0.5) + 1, rw, rh)

		local previousTile = nil
		local firstTile = nil
		for i, tile in pairs(ringTiles) do
			if previousTile ~= nil then
				local tx, ty = mapInfo.getXY(tile.offset)
				local px, py = mapInfo.getXY(previousTile.offset)
				local path = pg.getRandomPath(tx, ty, px, py, deviation, mapInfo)
				if path ~= nil then
					for _, item in ipairs(path) do
						local offset = mapInfo.getOffset(item.x, item.y)
						local plot = wrappedWorld.at(offset)
						if plot ~= nil then
							result[offset] = { x = item.x, y = item.y, plot = plot }
						end
					end
				end
			else
				firstTile = tile			
			end
			previousTile = tile
		end
		if previousTile ~= nil and firstTile ~= nil then
			local tx, ty = mapInfo.getXY(firstTile.offset)
			local px, py = mapInfo.getXY(previousTile.offset)
			local path = pg.getRandomPath(tx, ty, px, py, deviation, mapInfo)
			if path ~= nil then
				for _, item in ipairs(path) do
					local offset = mapInfo.getOffset(item.x, item.y)
					local plot = wrappedWorld.at(offset)
					if plot ~= nil then
						result[offset] = { x = item.x, y = item.y, plot = plot }
					end
				end
			end
		end
		return result
	end

	local putStuff = function(deviance, wide, high, type, condition)
		for offset, item in pairs(getRandomRing(deviance, fw / 3 * wide, fh / 3 * high)) do
			if condition == nil then
				item.plot.plotType = type
			else
				condition(item)
			end
		end
	end

	local randomModifier = 5

	local placeLandIfNotMountain = function(item)
		if item.plot.plotType ~= PlotTypes.PLOT_MOUNTAIN then
			item.plot.plotType = randomPlotType.get()
		end
	end

	local placeLand = function(item)
		item.plot.plotType = randomPlotType.get()
	end

	local placeLandRand = function(item)
		if Map.Rand(randomModifier, "Random value") < 1 then
			item.plot.plotType = randomPlotType.get()
		end
	end

	local placeMountainRand = function(item)
		if Map.Rand(randomModifier, "Random value") < 1 then
			item.plot.plotType = PlotTypes.PLOT_MOUNTAIN
		end
	end 

	local centerX = math.floor(mapInfo.width / 2)
	local centerY = math.ceil(mapInfo.height / 2)

	local placeLandIfAway = function(item)
		if Map.Rand(math.abs(math.floor(item.x - centerX)) + math.floor(centerX / 2), "Random value") / centerX > 0.3 then
			item.plot.plotType = randomPlotType.get()
		end
	end

	print("Circle - Set up random mountain ranges...")
	randomModifier = 6
	putStuff(0.9, 0.8, 0.8, PlotTypes.PLOT_MOUNTAIN, placeMountainRand)
	randomModifier = 5
	putStuff(0.9, 0.95, 0.8, PlotTypes.PLOT_MOUNTAIN, placeMountainRand)
	randomModifier = 3
	putStuff(0.9, 0.6, 0.9, PlotTypes.PLOT_MOUNTAIN)
	randomModifier = 2
	putStuff(0.9, 0.8, 0.8, PlotTypes.PLOT_MOUNTAIN)
	putStuff(1, 0.7, 0.7, PlotTypes.PLOT_MOUNTAIN)
	if mapInfo.height > 23 then
		putStuff(0.8, 0.8, 0.8, PlotTypes.PLOT_MOUNTAIN)
		putStuff(0.8, 0.75, 0.75, PlotTypes.PLOT_MOUNTAIN)
		putStuff(0.8, 0.75, 0.75, PlotTypes.PLOT_MOUNTAIN)
		putStuff(0.4, 0.9, 0.9, PlotTypes.PLOT_MOUNTAIN)
	end
	if mapInfo.height > 53 then
		putStuff(0.6, 0.9, 1, PlotTypes.PLOT_MOUNTAIN)
		putStuff(0.6, 1, 0.8, PlotTypes.PLOT_MOUNTAIN)
		putStuff(0.6, 0.7, 1, PlotTypes.PLOT_MOUNTAIN)

		randomModifier = 2
		putStuff(0.3, 1, 0.3, PlotTypes.PLOT_MOUNTAIN)
		putStuff(0.3, 1, 0.3, PlotTypes.PLOT_MOUNTAIN)
		randomModifier = 2
		putStuff(0.3, 0.3, 1, PlotTypes.PLOT_MOUNTAIN)
		randomModifier = 3
		putStuff(0.3, 0.3, 1, PlotTypes.PLOT_MOUNTAIN)
	end

	local circleType = Map.GetCustomOption(4)
	if circleType == 3 then
		circleType = 1 + Map.Rand(2, "Random CircleType - Lua");
	end

	print("Circle - Set up land...")
	if circleType == 1 then
		if mapInfo.height > 25 then
			putStuff(0.4, 1.2, 1.05, PlotTypes.PLOT_LAND, placeLand)
			putStuff(0.3, 1.2, 1.05, PlotTypes.PLOT_LAND, placeLand)
		end
		if mapInfo.height > 53 then
			randomModifier = 2
			putStuff(0.5, 1.2, 0.9, PlotTypes.PLOT_LAND, placeLand)
		end
	else
		if mapInfo.height > 25 then
			putStuff(0.3, 1.2, 1.05, PlotTypes.PLOT_LAND, placeLandRand)
			putStuff(0.3, 1.2, 1.05, PlotTypes.PLOT_LAND, placeLandRand)
		end
		if mapInfo.height > 53 then
			randomModifier = 3
			putStuff(0.4, 1.2, 1.05, PlotTypes.PLOT_LAND, placeLandRand)
		end
	end
	putStuff(0.5, 1, 1, PlotTypes.PLOT_LAND, placeLand)
	putStuff(0.8, 1, 1, PlotTypes.PLOT_LAND, placeLand)
	putStuff(0.8, 1, 1, PlotTypes.PLOT_LAND, placeLand)
	putStuff(0.9, 1, 1, PlotTypes.PLOT_LAND, placeLand)
	putStuff(0.3, 0.5, 0.6, PlotTypes.PLOT_LAND, placeLand)
	putStuff(0.5, 0.7, 0.7, PlotTypes.PLOT_LAND, placeLand)
	if mapInfo.height > 35 then
		--putStuff(0.4, 0.6, 0.6, PlotTypes.PLOT_LAND, placeLand)
		putStuff(0.4, 0.6, 0.5, PlotTypes.PLOT_LAND, placeLand)
		--putStuff(0.4, 0.5, 0.4, PlotTypes.PLOT_LAND, placeLand)
		--putStuff(0.6, 0.6, 0.6, PlotTypes.PLOT_LAND, placeLand)
		--putStuff(0.6, 0.8, 0.75, PlotTypes.PLOT_LAND, placeLand)
		--putStuff(0.6, 0.75, 0.75, PlotTypes.PLOT_LAND, placeLand)
	end
	if mapInfo.height > 53 then
		putStuff(0.4, 1, 0.3, PlotTypes.PLOT_LAND, placeLand)
		putStuff(0.4, 1, 0.3, PlotTypes.PLOT_LAND, placeLand)

		putStuff(0.4, 0.3, 1, PlotTypes.PLOT_LAND, placeLand)
		putStuff(0.4, 0.3, 1, PlotTypes.PLOT_LAND, placeLand)
	end
	--[[putStuff(0.7, 0.7, 0.7, PlotTypes.PLOT_LAND, placeLandIfNotMountain)
	putStuff(0.7, 0.7, 0.7, PlotTypes.PLOT_LAND, placeLandIfNotMountain)
	putStuff(0.6, 0.8, 0.8, PlotTypes.PLOT_LAND, placeLandIfNotMountain)
	putStuff(0.6, 0.8, 0.8, PlotTypes.PLOT_LAND, placeLandIfNotMountain)]]
	
	print("Circle - Create paths to middle sea...")

	local generateOceanExit = function(x, y, y2, deviance)
		local path = pg.getRandomPath(centerX, centerY, x, y, deviance, mapInfo)
		local index = 0
		local otherPath = nil
		if path ~= nil then
			for _, item in ipairs(path) do
				local offset = mapInfo.getOffset(item.x, item.y)
				local plot = wrappedWorld.at(offset)
				if plot ~= nil then
					plot.plotType = PlotTypes.PLOT_OCEAN
				end
				index = index + 1
				if index > 8 and otherPath == nil then
					otherPath = pg.getRandomPath(item.x, item.y, x, y2, deviance, mapInfo)
				end
			end
		end
		if otherPath ~= nil then
			for _, item in ipairs(otherPath) do
				local offset = mapInfo.getOffset(item.x, item.y)
				local plot = wrappedWorld.at(offset)
				if plot ~= nil then
					plot.plotType = PlotTypes.PLOT_OCEAN
				end
			end
		end
	end

	local rightRandomX = mapInfo.width - 3
	local leftRandomX = 3
	local partialHeight = math.floor(mapInfo.height / 2.5)
	local rightRandomY = Map.Rand(partialHeight, "Get random Y") + math.floor(partialHeight / 2)
	local leftRandomY = Map.Rand(partialHeight, "Get random Y") + math.floor(partialHeight / 2)
	local rightRandomY2 = mapInfo.height - rightRandomY
	local leftRandomY2 = mapInfo.height - leftRandomY

	generateOceanExit(leftRandomX, leftRandomY, leftRandomY2, 1)
	generateOceanExit(rightRandomX, rightRandomY, rightRandomY2, 1)

	print("Circle - Get all tiles...")
	local allTiles = wrappedWorld.tilesOf(function(plot)
		return true
	end)

	print("Circle - Remove small lakes or small islands...")
	for offset, plot in pairs(allTiles) do
		local x, y = mapInfo.getXY(offset)
		local numWater = 0
		local numLand = 0
		local numMountain = 0
		local ring = pg.getRing(x, y, 1, mapInfo)
		for _, item in ipairs(ring) do
			local aPlot = wrappedWorld.get(item.x, item.y)
			if aPlot ~= nil then
				if aPlot.plotType == PlotTypes.PLOT_OCEAN then
					numWater = numWater + 1
				elseif aPlot.plotType == PlotTypes.PLOT_MOUNTAIN then
					numMountain = numMountain + 1
				else
					numLand = numLand + 1
				end
			end
		end
		if numWater == 6 then
			plot.plotType = PlotTypes.PLOT_OCEAN
		elseif numMountain > 4 then
			for _, item in ipairs(ring) do
				local aPlot = wrappedWorld.get(item.x, item.y)
				if aPlot ~= nil then
					aPlot.plotType = randomPlotType.get()
				end
				aPlot = wrappedWorld.get(item.x, item.y)
				if aPlot ~= nil then
					aPlot.plotType = randomPlotType.get()
				end
			end
		elseif numMountain + numLand == 6 then
			if Map.Rand(2, "Random number") > 0 then
				plot.plotType = randomPlotType.get()
			end
		end
	end

	print("Circle - Generate terrain...")
	pg.setPlotTypes(wrappedWorld.array)

	GenerateCoasts();
end

----------------------------------------------------------------------------------
function GenerateTerrain()
	-- Get Temperature setting input by user.
	local temp = Map.GetCustomOption(1)
	if temp == 4 then
		temp = 1 + Map.Rand(3, "Random Temperature - Lua");
	end

	local args = {temperature = temp};
	local terraingen = TerrainGenerator.Create(args);

	terrainTypes = terraingen:GenerateTerrain();
	
	SetTerrainTypes(terrainTypes);
end
----------------------------------------------------------------------------------
function AddFeatures()
	print("Adding Features (Lua Pangaea) ...");

	-- Get Rainfall setting input by user.
	local rain = Map.GetCustomOption(2)
	if rain == 4 then
		rain = 1 + Map.Rand(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rain}
	local featuregen = FeatureGenerator.Create(args);

	-- False parameter removes mountains from coastlines.
	featuregen:AddFeatures(true);
end

function FixUnreachableResources()
	

	for i = 0, Map.GetNumPlots() - 1 do
		local plot = Map.GetPlotByIndex(i)
		local terrainType = plot:GetTerrainType()
		if terrainType == TerrainTypes.TERRAIN_COAST or terrainType == TerrainTypes.TERRAIN_OCEAN then
			local resourceType = plot:GetResourceType(-1)
			if resourceType ~= -1 then 
				-- find mountains
				local nearMountainItems = dice.Items()
				local mountainItems = dice.Items()
				local nearItems = 0
				local numMountain = 0
				local numOther = 0
				local cx, cy = mapInfo.getXY(i + 1)
				for range = 1, 3 do
					for _, item in ipairs(pg.getRing(cx, cy, range, mapInfo)) do
						local ox, oy = mapInfo.fixWrap(item.x, item.y)
						local otherPlot = Map.GetPlot(ox, oy)
						if otherPlot ~= nil then
							local otherPlotType = otherPlot:GetPlotType()
							local otherTerrainType = otherPlot:GetTerrainType()
							if otherTerrainType ~= TerrainTypes.TERRAIN_COAST and otherTerrainType ~= TerrainTypes.TERRAIN_OCEAN then
								if otherPlotType == PlotTypes.PLOT_MOUNTAIN then
									if range == 1 then
										nearMountainItems.add({ x = ox, y = oy })
										nearItems = nearItems + 1
									else
										mountainItems.add({ x = ox, y = oy })
									end
									numMountain = numMountain + 1
								else
									numOther = numOther + 1
								end
							end
						end
					end
				end
				
				local randomPlotType = dice.Items(PlotTypes.PLOT_LAND, PlotTypes.PLOT_HILLS)

				if numOther < 2 and numMountain > 0 then
					if nearItems > 0 then
						local item = nearMountainItems.get()
						local mPlot = Map.GetPlot(item.x, item.y)
						mPlot:SetPlotType(randomPlotType.get())
					else
						local item = mountainItems.get()
						local mPlot = Map.GetPlot(item.x, item.y)
						mPlot:SetPlotType(randomPlotType.get())
						item = mountainItems.get()
						mPlot = Map.GetPlot(item.x, item.y)
						mPlot:SetPlotType(randomPlotType.get())
					end
				end
			end
		end
	end

	Map.RecalculateAreas();
end

function StartPlotSystem()
	-- Get Resources setting input by user.
	local res = Map.GetCustomOption(3)
	if res == 6 then
		res = 1 + Map.Rand(3, "Random Resources Option - Lua");
	end

	print("Creating start plot database.");
	local start_plot_database = AssignStartingPlots.Create()
	
	print("Dividing the map in to Regions.");
	-- Regional Division Method 1: Biggest Landmass
	local args = {
		method = 1,
		resources = res,
		};
	start_plot_database:GenerateRegions(args)

	print("Choosing start locations for civilizations.");
	start_plot_database:ChooseLocations()
	
	print("Normalizing start locations and assigning them to Players.");
	start_plot_database:BalanceAndAssign()

	print("Placing Natural Wonders.");
	start_plot_database:PlaceNaturalWonders()

	print("Placing Resources and City States.");
	start_plot_database:PlaceResourcesAndCityStates()

	print("Circle - Removing unreachable resources.");
	FixUnreachableResources()
end

function GenerateMap()
	print("Generating Map with Olympic World");

	-- This is the core map generation function.
	-- Every step in this process carries dependencies upon earlier steps.
	-- There isn't any way to change the order of operations without breaking dependencies,
	-- although it would be possible to repair and reorganize certain dependencies with enough work.
	
	-- Plot types are the core layer of the map, determining land or sea, determining flatland, hills or mountains.
	GeneratePlotTypes();
	
	-- Terrain covers climate: grassland, plains, desert, tundra, snow.
	GenerateTerrain();
	
	-- Each body of water, area of mountains, or area of hills+flatlands is independently grouped and tagged.
	Map.RecalculateAreas();
	
	-- River generation is affected by plot types, originating from highlands and preferring to traverse lowlands.
	AddRivers();
	
	-- Lakes would interfere with rivers, causing them to stop and not reach the ocean, if placed any sooner.
	AddLakes();
	
	-- Features depend on plot types, terrain types, rivers and lakes to help determine their placement.
	AddFeatures();

	-- Feature Ice is impassable and therefore requires another area recalculation.
	Map.RecalculateAreas();

	-- Assign Starting Plots, Place Natural Wonders, and Distribute Resources.
	-- This system was designed and programmed for Civ5 by Bob Thomas.
	-- Starting plots are wholly dependent on all the previous elements being in place.
	-- Natural Wonders are dependent on civ starts being in place, to keep them far enough away.
	-- Resources are dependent on start locations, Natural Wonders, as well as plots, terrain, rivers, lakes and features.
	--
	-- This system relies on Area-based data and cannot tolerate an AreaID recalculation during its operations.
	-- Due to plot changes from Natural Wonders and possibly other source, another recalculation is done as the final action of the system.
	StartPlotSystem();

	-- Goodies depend on not colliding with resources or Natural Wonders, or being placed too near to start plots.
	AddGoodies();

	-- Continental artwork selection must wait until Areas are finalized, so it gets handled last.
	DetermineContinents();
end