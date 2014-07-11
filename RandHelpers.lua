-- RandHelpers
-- Author: Nerijus
-- DateCreated: 10/5/2010 9:59:41 PM
-- Version 1.1
--------------------------------------------------------------
include("MapGenerator");

dice = {}

--[[
Gets random item from the list of items
--]]
dice.Items = function(...)
	
	local items = {}
	local count = 0

	local self = {
		add = function(...)
			for _, item in ipairs(arg) do
				table.insert(items, item)
				count = count + 1
			end
		end,
		get = function()
			if count == 0 then
				return nil
			else
				local rnd = Map.Rand(count, "Random item in item list") + 1
				return items[rnd]
			end
		end,
		size = function()
			return count
		end,
	}

	for _, item in ipairs(arg) do
		self.add(item)
	end
	
	return self
end

--[[
Gets random item from the list of items, based on item weight (or importance)

Arguments to constructor can be passed as { weight, item }
Don't use negative weights!
For best performance, put highest weighted items first!
--]]
dice.WeightedItems = function(...)
	
	local maxRandomNumber = 34000

	local items = {}
	local count = 0
	local sum = 0
	local min_weight = nil
	local max_weight = nil
	local density = nil

	local self = {
		add = function(weight, item)
			if weight > 0 then
				items[weight] = item
				count = count + 1
				if min_weight == nil or weight < min_weight then
					min_weight = weight
				end
				if max_weight == nil or weight > max_weight then
					max_weight = weight
				end
				sum = sum + weight
				density = nil -- reset density on modification
			end
		end,
		get = function()
			if density == nil then
				density = min_weight
				if density > 1 then
					local remainder = sum - math.floor(sum)
					if remainder == 0 then
						density = 1
					elseif remainder > 0.07 then
						density = remainder
					else
						density = 0.3
					end
				end
				if sum / density > maxRandomNumber then
					density = sum / maxRandomNumber
				end
			end
			local rnd = (Map.Rand(math.floor(sum / density), "Random weighted item in item list") + 1) * density
			local target = 0
			local last_item = nil
			for weight, item in pairs(items) do
				target = target + weight
				if rnd <= target then
					return item
				end
				last_item = item
			end
			return last_item
		end,
		size = function()
			return count
		end,
	}

	for _, item in ipairs(arg) do
		self.add(item[1], item[2])
	end
	
	return self
end