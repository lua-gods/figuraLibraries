local lib = {}
local tails = {} ---@type auria.trail_tail[]
---@class auria.trail_tail
---@field start ModelPart
---@field points Vector3[]
---@field oldPoints Vector3[]
---@field distances number[]
---@field sizes Vector3[]|number[]
---@field vels Vector3[]
---@field config {stiff: number, bounce: number, gravity: Vector3, maxDist: number}
local trailingTail = {}

-- variables for optimziation
local min = math.min
local max = math.max
local getBlockState = world.getBlockState
local table_insert = table.insert

---creates new trailing tail
---@param model ModelPart|ModelPart[]
---@return auria.trail_tail
function lib.new(model)
   local tail = {}
   tail.config = {
      bounce = 0.2,
      stiff = 0.4,
      gravity = vec(0, -0.05, 0),
      -- gravity = vec(0, 0, 0),
      maxDist = 1.25
   }
   tail.points = {}
   tail.distances = {}
   tail.sizes = {}
   for _ = 1, 32 do
      table.insert(tail.points, vec(0, 0, 0))
      table.insert(tail.distances, 0.2)
      table.insert(tail.sizes, 0.4)
   end
   tail.vels = {}
   tail.points[0] = vec(0, 0, 0)
   tail.oldPoints = {}
   for i in pairs(tail.points) do
      tail.vels[i] = vec(0, 0, 0)
      tail.oldPoints[i] = tail.points
   end
   tail.start = models:newPart(''):pivot(0, 14, 2)
   local id = #tails + 1
   tails[id] = tail
   return tail
end

local function debugPoint(pos, color)
   particles['end_rod']
      :pos(pos)
      :color(color or vec(1, 1, 1))
      :scale(0.5)
      :lifetime(2)
      :gravity(0)
      :spawn()
end

---@overload fun(pos1: Vector3, pos2: Vector3, size: number|Vector3): { [1]: Vector3, [2]: Vector3 }[]
local function generateAabbs(pos1, pos2, size)
   local aabbs = {}
   local minPos = (vec(
      min(pos1.x, pos2.x),
      min(pos1.y, pos2.y),
      min(pos1.z, pos2.z)
   ) - size):floor()
   local maxPos = (vec(
      max(pos1.x, pos2.x),
      max(pos1.y, pos2.y),
      max(pos1.z, pos2.z)
   ) + size):ceil()
   for x = minPos.x, maxPos.x do
      for y = minPos.y, maxPos.y do
         for z = minPos.z, maxPos.z do
            local pos = vec(x, y, z)
            for _, v in pairs(getBlockState(pos):getCollisionShape()) do
               table_insert(aabbs, {v[1] + pos - size, v[2] + pos + size})
            end
         end
      end
   end
   return aabbs
end

---@overload fun(pos: Vector3, newPos: Vector3): Vector3
local function movePointWithCollision(pos, newPos, size)
   for axis = 1, 3 do
      local endPos = pos:copy()
      endPos[axis] = newPos[axis]
      local aabbs = generateAabbs(pos, endPos, size)
      local aabb, hitpos = raycast:aabb(pos, endPos, aabbs)
      pos = hitpos or endPos
   end
   return pos
end

local log = {}
local m = models:newPart('', 'Hud'):newText(''):outline(true):pos(-2, -2, 0)

---@overload fun(tail: auria.trail_tail)
local function tickTail(tail)
   for i, v in pairs(tail.points) do
      tail.oldPoints[i] = v
   end

   local startWorldMat = tail.start:partToWorldMatrix()
   if startWorldMat.v11 == startWorldMat.v11 then -- check if not NaN
      tail.points[0] = startWorldMat:apply()
   end
   log = {}
   for i, pos in ipairs(tail.points) do
      local previous = tail.points[i - 1]
      local dist = tail.distances[i]
      -- table.insert(log, tostring(pos - previous))
      -- table.insert(log, '---')
      local offset = pos - previous
      local offsetLength = offset:length()
      local dir = offsetLength > 0.01 and offset / offsetLength or vec(0, 0, 1) -- prevent normalized vector being length 0 when its vec(0, 0, 0)
      local targetPos = previous + dir * dist

      pos = targetPos + (pos - targetPos):clamped(0, dist * tail.config.maxDist)

      tail.vels[i] = tail.vels[i] * (1 - tail.config.stiff) + (targetPos - pos) * tail.config.bounce + tail.config.gravity
      
      local newPos = pos + tail.vels[i]:clamped(0, 50)
      
      -- local pos2 = pos
      -- local SIDE = ''
      -- for axis = 1, 3 do
         -- local endPos = pos:copy()
         -- endPos[axis] = newPos[axis]
         -- local _, hitPos, side = raycast:block(pos, endPos, "COLLIDER", "NONE")
         -- SIDE = SIDE..side..'  '
         -- if (hitPos - pos):length() > 0.001 then
            -- pos = hitPos
         -- end
      -- end
      -- table.insert(log, tostring(pos2 - pos))
      -- table.insert(log, SIDE)
      -- tail.points[i] = pos
      
      tail.points[i] = movePointWithCollision(pos, newPos, tail.sizes[i])
   end

   m:text(table.concat(log, '\n'))
end

local lineLib = require('GNLineLib')
local lines = {} ---@type line[][]

---@overload fun(tail: auria.trail_tail, delta: number)
local function renderTail(tail, delta)
   -- debugPoint(tail.start:partToWorldMatrix():apply())
   for i, posNew in ipairs(tail.points) do
      local pos = math.lerp(tail.oldPoints[i], posNew, delta) --[[@as Vector3]]
      local oldPos = math.lerp(tail.oldPoints[i - 1], tail.points[i - 1], delta) --[[@as Vector3]]
      if not lines[i] then
         lines[i] = {
            [-1] = lineLib:new(),
            lineLib:new():setWidth(0.08):setDepth(-0.05),
            lineLib:new():setWidth(0.02):setDepth(-0.25),
            lineLib:new():setWidth(0.02):setDepth(-0.5),
            lineLib:new():setWidth(0.02):setDepth(-0.8),
         }
      end
      local distOffset = (pos - oldPos):length()
      local dist = tail.distances[i]
      distOffset = distOffset > dist and (distOffset - dist) / (dist * 0.5) or distOffset / dist - 1
      distOffset = math.clamp(distOffset, -1, 1)
      local color = math.lerp(
         vec(1, 1, 1),
         distOffset > 0 and vec(1, 0, 0) or vec(0, 1, 0),
         math.abs(distOffset)
      )
      for k, v in pairs(lines[i]) do
         v:setA(pos)
         v:setB(oldPos)
         v:setColor(k > 0 and color or color * 0.5)
      end
   end
end

function events.tick()
   if not next(tails) then return end
   for _, tail in pairs(tails) do
      tickTail(tail)
   end
end

function events.render(delta)
   if not next(tails) then return end
   for _, tail in pairs(tails) do
      renderTail(tail, delta)
   end
end

return lib