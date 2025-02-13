--[[______   __
  / ____/ | / / by: GNamimates, Discord: "@gn8.", Youtube: @GNamimates
 / / __/  |/ / Simple wait function
/ /_/ / /|  / can sleep
\____/_/ |_/ Source: link]]
local queries = {}
local process

local MAX_QUERIES = 1000

local function setProcessActive(isActive)
	events.WORLD_RENDER[isActive and "register" or "remove"](events.WORLD_RENDER,process)
end

process = function ()
	local time = client:getSystemTime()
	for i = 1, MAX_QUERIES, 1 do
		if queries[1].time <= time then
			queries[1].callback()
			table.remove(queries,1)
			if #queries == 0 then setProcessActive(false) return end
		end
	end
end

local function insert(targetTime,callback,i)
	table.insert(queries, i, {time = targetTime, callback = callback})
	if #queries == 1 then setProcessActive(true) end
end

---Makes a given callback function wait for the given `ms` miliseconds.
---@param ms integer
---@param callback function
function _G.wait(ms, callback)
	local targetTime = client:getSystemTime() + ms
	local count = #queries
	for i = 1, count, 1 do
		if queries[i].time > targetTime then
			insert(targetTime, callback, i)
			return
		end
	end
	insert(targetTime, callback, count+1)
end