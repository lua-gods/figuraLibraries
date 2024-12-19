local lib = {}
local tails = {} ---@type auria.trail_tail[]
---@class auria.trail_tail
---@field start ModelPart
---@field points Vector3[]
---@field oldPoints Vector3[]
---@field distances number[]
---@field sizes Vector3[]|number[]
---@field vels Vector3[]
---@field oldDir Vector3
---@field config {stiff: number, bounce: number, gravity: Vector3, maxDist: number, maxAngle: number}
local trailingTail = {}

local worldModel = models:newPart('trail_tails', 'World')

-- variables for optimziation
local min = math.min
local max = math.max
local getBlockState = world.getBlockState
local table_insert = table.insert

local function directionToEular(dirVec)
   local yaw = math.atan2(dirVec.x, dirVec.z)
   local pitch = math.atan2(dirVec.y, dirVec.xz:length())
   return vec(-math.deg(pitch), math.deg(yaw), 0)
end

---creates new trailing tail
---@param modelList ModelPart[]
---@return auria.trail_tail
function lib.new(modelList)
   local tail = {}
   tail.config = {
      bounce = 0.4,
      stiff = 0.5,
      gravity = vec(0, -0.02, 0),
      -- gravity = vec(0, 0, 0),
      maxDist = 1.1,
      maxAngle = 20
   }
   tail.points = {}
   tail.distances = {}
   tail.sizes = {}
   -- for _ = 1, #modelList - 1 do
      -- table.insert(tail.points, vec(0, 0, 0))
      -- table.insert(tail.distances, 0.2)
      -- table.insert(tail.sizes, 0.2)
   -- end
   local oldPivot = modelList[1]:getPivot()
   tail.start = modelList[1]:getParent():newPart('trail_tail_point'):pivot(oldPivot):rot(modelList[1]:getRot())
   for i = 2, #modelList do
      local pivot = modelList[i]:getPivot()
      tail.distances[i - 1] = (pivot - oldPivot):length() / 16
      tail.sizes[i - 1] = 0.2
      oldPivot = pivot
      modelList[i]:moveTo(worldModel)
      -- model[i].preRender = function(delta, context, part)
      --    part:setPos(
      --       math.lerp(tail.oldPoints[i - 1], tail.points[i - 1], delta) * 16 - pivot
      --    )
      -- end
   end
   modelList[1]:moveTo(worldModel)
   table.insert(tail.distances, 0.1)
   table.insert(tail.sizes, 0)

   -- tail.start.preRender = function(delta)
   tail.start.midRender = function(delta)
   -- modelList[1].midRender = function(delta)
   -- function events.post_render(delta)
      local point0 = math.lerp(tail.oldPoints[0], tail.points[0], delta)
      local offset = vec(0, 0, 0)
      local tailStart = tail.start:partToWorldMatrix():apply()
      if tailStart.x == tailStart.x then
         offset = tailStart - point0
      end
      local nextPos = math.lerp(tail.oldPoints[0], tail.points[0], delta) + offset
      local pos = nextPos
      for i, model in pairs(modelList) do
         i = i - 1
         pos = nextPos
         nextPos = math.lerp(tail.oldPoints[i + 1], tail.points[i + 1], delta) + offset
         local dir = (nextPos - pos):normalize()
         model:setPos(pos * 16 - model:getPivot())
            :setRot(directionToEular(dir))
      end
   end

   tail.vels = {}
   tail.points[0] = vec(0, 0, 0)
   tail.oldPoints = {[0] = vec(0, 0, 0)}
   tail.oldDir = vec(0, 0, 1)
   for i = 1, #tail.distances do
      tail.vels[i] = vec(0, 0, 0)
      tail.points[i] = vec(0, 0, 0)
      tail.oldPoints[i] = vec(0, 0, 0)
   end

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
      tail.oldDir = startWorldMat:applyDir(0, 0, 1):normalize()
   end

   log = {}

   local oldDir = tail.oldDir
   for i, pos in ipairs(tail.points) do
      local previous = tail.points[i - 1]
      local dist = tail.distances[i]
      -- table.insert(log, tostring(pos - previous))
      -- table.insert(log, '---')
      local offset = pos - previous
      local offsetLength = offset:length()
      local dir = offsetLength > 0.01 and offset / offsetLength or vec(0, 0, 1) -- prevent normalized vector being length 0 when its vec(0, 0, 0)
      local angle = math.deg(math.acos(dir:dot(oldDir)))
      local maxAngle = tail.config.maxAngle
      if angle > maxAngle then -- clamp angle
         local rotAxis = oldDir:crossed(dir)
         if rotAxis:lengthSquared() > 0.1 then
            dir = vectors.rotateAroundAxis(math.min(angle, maxAngle) - angle, dir, rotAxis):normalize()
         end
      end
      
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

      oldDir = dir
   end

   m:text(table.concat(log, '\n'))
end

local lineLib = require('GNLineLib')
local lines = {} ---@type line[][]

---@overload fun(tail: auria.trail_tail, delta: number)
local function renderTail(tail, delta)
   -- debugPoint(tail.start:partToWorldMatrix():apply())
   -- debug lines
   do return end
   for i, posNew in ipairs(tail.points) do
      local pos = math.lerp(tail.oldPoints[i], posNew, delta) --[[@as Vector3]]
      local oldPos = math.lerp(tail.oldPoints[i - 1], tail.points[i - 1], delta) --[[@as Vector3]]
      if not lines[i] then
         lines[i] = {
            [-1] = lineLib:new(),
            lineLib:new():setWidth(0.08):setDepth(-0.05),
            lineLib:new():setWidth(0.01):setDepth(-0.25),
            lineLib:new():setWidth(0.01):setDepth(-0.5),
            lineLib:new():setWidth(0.01):setDepth(-0.8),
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