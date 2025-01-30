local lib = {}
local tails = {} ---@type auria.trail_tail[]
---@class auria.trail_tail
---@field start ModelPart
---@field points Vector3[]
---@field oldPoints Vector3[]
---@field distances number[]
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
      bounce = 0.2,
      stiff = 0.3,
      gravity = vec(0, -0.04, 0),
      -- gravity = vec(0, 0, 0),
      maxDist = 1.5,
      maxAngle = 20
   }
   tail.points = {}
   tail.distances = {}

   for _ = 1, 20 do
      table.insert(tail.distances, 0.2)
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

---@overload fun(Pos: Vector3): Vector3?
local function isPointInWall(pos)
   local block = world.getBlockState(pos)
   local p = pos - block:getPos()
   for _, col in pairs(block:getCollisionShape()) do
      if p >= col[1] and p <= col[2] then
         return p - (col[1] + col[2]) * 0.5
      end
   end
end

---@overload fun(pos: Vector3, newPos: Vector3): Vector3
local function movePointWithCollision(pos, newPos)
   for axis = 1, 3 do
      local targetPos = pos:copy()
      targetPos[axis] = newPos[axis]
      local _, hitPos = raycast:block(pos, targetPos)
      local offset = hitPos - pos
      pos = pos + offset:clamped(0, math.max(offset:length() - 0.001, 0))
   end
   local push = isPointInWall(pos)
   if push then
      pos = pos + push:normalize() * 0.01
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
   tail.points[0] = player:getPos() + vec(0, 12 / 16, 0)

   log = {}

   local oldDir = tail.oldDir
   for i, pos in ipairs(tail.points) do
      local previous = tail.points[i - 1]
      local dist = tail.distances[i]
      local maxDist = tail.distances[i] * tail.config.maxDist
      -- table.insert(log, tostring(pos - previous))
      -- table.insert(log, '---')
      local offset = pos - previous
      local offsetLength = offset:length()
      local dir = offsetLength > 0.01 and offset / offsetLength or vec(0, 0, 1) -- prevent normalized vector being length 0 when its vec(0, 0, 0)
      -- clamp angle
      local targetDir = dir
      local angle = math.deg(math.acos(dir:dot(oldDir)))
      local maxAngle = tail.config.maxAngle
      if angle > maxAngle then -- clamp angle
         local rotAxis = oldDir:crossed(dir)
         if rotAxis:lengthSquared() > 0.1 then
            targetDir = vectors.rotateAroundAxis(math.min(angle, maxAngle) - angle, dir, rotAxis):normalize()
         end
      end
      local targetPos = previous + targetDir * maxDist
      -- clamp distance
      pos = previous + dir * math.min(offsetLength, dist)
      -- pull or push to desired length
      local targetOffset = targetPos - pos
      -- local targetOffset = (targetPos - pos):clamped(0, dist * tail.config.maxDist)
      -- local pullPushStrength = (previous - pos):length() / (dist * tail.config.maxDist)
      -- pullPushStrength = math.abs(pullPushStrength - 1)
      -- pullPushStrength = math.min(pullPushStrength, 1)
      -- pullPushStrength = pullPushStrength ^ 0.25
      -- pullPushStrength = pullPushStrength * tail.config.bounce
      -- table.insert(log, math.floor(pullPushStrength * 10000) / 10000)

      -- pos = targetPos - targetOffset

      tail.vels[i] = tail.vels[i] * (1 - tail.config.stiff)
      tail.vels[i] = tail.vels[i] + targetOffset * tail.config.bounce
      -- tail.vels[i] = tail.vels[i] + (targetOffset) * pullPushStrength
      tail.vels[i] = tail.vels[i] + tail.config.gravity
      
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
      
      tail.points[i] = movePointWithCollision(pos, newPos)

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
   -- do return end
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