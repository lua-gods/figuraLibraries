-- variables
local lib = {}

---@class AuriaEvent
local eventMetatable = {__type = "Event", __index = {}}
local eventsMetatable = {__index = {}}
eventMetatable.__index = eventMetatable

---@return AuriaEvent
function lib.new()
   return setmetatable({_registered = {}}, eventMetatable)
end
---@return AuriaEvent
function lib.newEvent()
   return setmetatable({_registered = {}}, eventMetatable)
end

function lib.table(tbl)
   return setmetatable({_table = tbl or {}}, eventsMetatable)
end

---Registers an event
---@param func function
---@param name string?
function eventMetatable:register(func, name)
   table.insert(self._registered, {func = func, name = name})
end

---Clears all event
function eventMetatable:clear()
   self._registered = {}
end

---Removes an event with the given name.
---@param match string
---@return integer
function eventMetatable:remove(match)
   local count = 0
   for i = #self._registered, 1, -1 do
      local tbl = self._registered[i]
      if tbl.func == match or tbl.name == match then
         table.remove(self._registered, i)
         count = count + 1
      end
   end
   return count
end

---Returns how much listerners there are.
---@param name string
---@return integer
function eventMetatable:getRegisteredCount(name)
   local count = 0
   for _, data in pairs(self._registered) do
      if data.name == name then
         count = count + 1
      end
   end
   return count
end

function eventMetatable:__call(...)
   local returnValue = {}
   for _, data in pairs(self._registered) do
      table.insert(returnValue, {data.func(...)})
   end
   return returnValue
end

function eventMetatable:invoke(...)
   local returnValue = {}
   for _, data in pairs(self._registered) do
      table.insert(returnValue, {data.func(...)})
   end
   return returnValue
end

function eventMetatable:__len()
   return #self._registered
end

-- events table
function eventsMetatable.__index(t, i)
   return t._table[i] or (type(i) == "string" and getmetatable(t._table[i:upper()]) == eventMetatable) and t._table[i:upper()] or nil
end

function eventsMetatable.__newindex(t, i, v)
   if type(i) == "string" and type(v) == "function" and t._table[i:upper()] and getmetatable(t._table[i:upper()]) == eventMetatable then
      t._table[i:upper()]:register(v)
   else
      t._table[i] = v
   end
end

function eventsMetatable.__ipairs(t)
   return ipairs(t._table)
end
function eventsMetatable.__pairs(t)
   return pairs(t._table)
end

-- return library
return lib
