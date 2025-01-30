local vel = vec(0, 0, 0)
local oldPos = vec(0, 0, 0)
local pos = vec(0, 0, 0)
local rot = 0
local oldRot = 0
local enabled = false
local turnSmooth = 0

local keys = {
   {'key.forward', vec(1, 0, 0), 0},
   {'key.back', vec(-1, 0, 0), 0},
   {'key.right', vec(0, 0, 0), 1},
   {'key.left', vec(0, 0, 0), -1},
   {'key.jump', vec(0, 1.5, 0), 0},
}

for _, v in pairs(keys) do
   v.key = keybinds:fromVanilla(v[1])
   v.key.press = function()
      return enabled
   end
end

keybinds:of("car", "key.keyboard.grave.accent").press = function()
   if not player:isLoaded() then return end
   enabled = not enabled
   oldPos = player:getPos()
   pos = player:getPos()
   vel = vec(0, 0, 0)
   renderer:setCameraPivot()
   renderer:setCameraRot()
end

---@overload fun(Pos: Vector3): Vector3?
local function isPointInWall(Pos)
   local block = world.getBlockState(Pos)
   local p = Pos - block:getPos()
   for _, col in pairs(block:getCollisionShape()) do
      if p >= col[1] and p <= col[2] then
         return p - (col[1] + col[2]) * 0.5
      end
   end
end

function events.tick()
   if not enabled then return end
   oldPos = pos
   oldRot = rot
   rot = rot % 360

   local onGround = isPointInWall(pos - vec(0, 0.01, 0))

   local turn = 0
   for _, v in pairs(keys) do
      if v.key:isPressed() then
         vel = vel + v[2] * (onGround and vec(1, 0, 1) * 0.3 + vec(0, 1, 0) or vec(1, 0, 1) * 0.01)
         turn = turn + v[3] * 30
      end
   end
   turnSmooth = math.lerp(turnSmooth, turn, 0.8)
   vel = vel * (onGround and 0.5 or 0.98)
   vel.y = vel.y - 0.08
   rot = rot + turnSmooth * vel.x
   local newPos = pos + vectors.rotateAroundAxis(270 - rot, vel, vec(0, 1, 0))
   -- if not isPointInWall(pos) then
   for axis = 1, 3 do
      local targetPos = pos:copy()
      targetPos[axis] = newPos[axis]
      local _, hitPos = raycast:block(pos, targetPos)
      local offset = hitPos - pos
      pos = pos + offset:clamped(0, math.max(offset:length() - 0.001, 0))
   end
   local push = isPointInWall(pos)
   if push then
      pos = pos + push * 0.1
   end
   if not renderer:isFirstPerson() then
      particles['end_rod']:lifetime(2):pos(pos):setScale(0.5):spawn()
   end
end

function events.world_render(delta)
   if not enabled then
      return
   end
   renderer:setCameraPivot(math.lerp(oldPos, pos, delta) + vec(0, 0.2, 0))
   renderer:setCameraRot(0, math.lerpAngle(oldRot, rot, delta), 0)
end