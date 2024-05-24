local tailPhysics = {} -- made by Auriafoxgirl
---@class auria.tailPhysics
---@field config table
---@field model ModelPart
local tail = {}
local updatingTails = {}
tail.__index = tail

---creates new tail physics
---@param model ModelPart|[ModelPart]
function tailPhysics.new(model)
   local obj = setmetatable({}, tail)
   obj.config = { -- default config
      velocityStrength = vec(1, 1, 1), -- left right, up down, forward backward
   
      rotVelocityStrength = 1,
      rotVelocityLimit = 10,
   
      verticalVelocityMin = -5,
      verticalVelocityMax = 2,
   
      bounce = 0.1, -- how bouncy tail will be, can also be vector 4
      stiff = 0.18, -- how stiff should tail be, can also be vector 4
      waterStiff = 0.5, -- how stiff should tail be underwater
      waterStrength = 0.5, -- how much water will affect tail
   
      idleSpeed = vec(0, 0, 0), -- how fast should tail move when nothing is happening
      idleStrength = vec(0, 0, 0), -- how much should tail move
      walkSpeed = vec(0, 0.5, 0), -- how much faster should tail move when walking
      walkStrength = vec(0, 6, 0), -- how much tail will move when walking
      walkLimit = 0.31, -- maximum speed that will be used for walkSpeed, set it to 0 to disable
      wagSpeed = vec(0, 0.6, 0), -- how fast tail moves when wagging with tail
      wagStrength = vec(1, 12, 0), -- how much it should move
      enableWag = {}, -- if any variable in this table is true tail will wag
   
      tailOffset = 0.5, -- offset for wag or something
      tailDelay = 6, -- amount of ticks last tail part will be delayed from first one
   
      -- table containing functions with argument rot that is table of vector 4 (default 0, 0, 0, 1) that controls tail rotation, returning true will stop physics, can be used for sleeping animation
      rotOverride = {}
   }
   -- model
   obj.defaultRot = {}
   if type(model) == 'table' then
      obj.parts = model
      for i, v in pairs(model) do
         obj.defaultRot[i] = v:getRot()
      end
   else
      obj.parts = {}
      local currentPart = model
      local n, i = currentPart:getName():match("^(.-)(-?%d*)$")
      i = tonumber(i) or 1
      while currentPart do
         table.insert(obj.parts, currentPart)
         table.insert(obj.defaultRot, currentPart:getRot())
         i = i + 1
         currentPart = currentPart[n .. i]
      end
   end
   obj.tailY = obj.parts[1]:getPivot().y / 16
   -- rot
   obj.rot = {vec(0, 0, 0, 1)}
   obj.oldRot = {vec(0, 0, 0, 1)}
   obj.tailDelay = 0
   -- vel
   obj.vel = vec(0, 0, 0, 0)
   -- wag
   obj.wagTime, obj.oldWagTime = vec(0, 0, 0), vec(0, 0, 0)
   obj.wagSpeed = vec(0, 0, 0)
   obj.wagStrength, obj.oldWagStrength = vec(0, 0, 0), vec(0, 0, 0)
   -- finish
   updatingTails[obj] = obj
   return obj
end

---merge new config with current config, returns self for chaining
---@param tbl table
---@return self
function tail:setConfig(tbl)
   for i, v in pairs(tbl) do
      self.config[i] = v
   end
   return self
end

---set if tail should update, coudld be used for disabling tail when invisible, returns self for chaining
---@param x boolean
---@return self
function tail:setUpdate(x)
   updatingTails[self] = x and self or nil
   return self
end

---remove tail physics from tail
function tail:remove()
   updatingTails[self] = nil
end

local function getPartRot(self, i, delta, time, strength)
   local k = math.floor((i - 1) / #self.parts * self.tailDelay) + 1
   local r = math.lerp(self.oldRot[k], self.rot[k], delta or 1)
   return r.xyz + self.defaultRot[i] * r.w + (time - self.config.tailOffset * i):applyFunc(math.cos) * strength
end

--- returns tail rotation for given part id
--- @overload fun(partId: number, delta?: number): Vector3
function tail:getPartRot(partId, delta)
   delta = delta or 1
   local time = math.lerp(self.oldWagTime, self.wagTime, delta)
   local strength = math.lerp(self.oldWagStrength, self.wagStrength, delta)
   return getPartRot(self, partId, delta, time, strength)
end

local function getUnderwaterlevel(pos)
   local y = -1
   for i = -1, 2 do
      local bl = world.getBlockState(pos + vec(0, i, 0))
      if #bl:getFluidTags() >= 1 then
         local waterHeight = 0.85 - (bl.properties.level or 0) / 10
         y = i + waterHeight - pos.y % 1
      end
   end
   return y
end

local function tickTail(tail, playerVelRaw, bodyVel, waterStrength, wagWalkSpeed)
   -- update tail delay if changed
   if tail.tailDelay ~= tail.config.tailDelay then
      tail.tailDelay = tail.config.tailDelay
      tail.rot = {}
      tail.oldRot = {}
      for i = 1, tail.tailDelay do
         tail.rot[i], tail.oldRot[i] = vec(0, 0, 0, 1), vec(0, 0, 0, 1)
      end
   end
   -- update rot
   tail.rot[0] = tail.rot[1]
   for i = tail.tailDelay, 1, -1 do
      tail.oldRot[i] = tail.rot[i]
      tail.rot[i] = tail.rot[i - 1]:copy()
   end
   -- update variables
   tail.oldWagTime = tail.wagTime
   tail.oldWagStrength = tail.wagStrength
   -- override
   for _, v in ipairs(tail.config.rotOverride) do
      if v(v.rot) then
         v.wagTime = v.wagTime * 0.8
         v.wagStrength = v.wagStrength * 0.8
         return
      end
   end
   -- get velocity
   bodyVel = math.clamp(bodyVel * tail.config.rotVelocityStrength * 0.2, -tail.config.rotVelocityLimit, tail.config.rotVelocityLimit)
   local wagWalkSpeed = tail.config.walkLimit == 0 and 0 or math.clamp(playerVelRaw.z * tail.config.velocityStrength.z / tail.config.walkLimit * wagWalkSpeed, 0, 1)
   local playerVel = playerVelRaw * tail.config.velocityStrength
   -- water level
   local tailPos = player:getPos():add(0, tail.tailY, 0)
   local waterLevel = getUnderwaterlevel(tailPos)
   local inWater = math.clamp(waterLevel + 0.5, 0, 1) * tail.config.waterStrength * waterStrength
   -- apply velocity
   tail.vel = tail.vel * (1 - math.lerp(tail.config.stiff, tail.config.waterStiff, inWater))
   tail.vel = tail.vel + (vec(0, 0, 0, 1) - tail.rot[1]) * tail.config.bounce
   tail.rot[1] = tail.rot[1] + tail.vel

   tail.rot[1].x = tail.rot[1].x + math.clamp(playerVel.y * 5 - inWater * 4, tail.config.verticalVelocityMin, tail.config.verticalVelocityMax)
   tail.rot[1].y = tail.rot[1].y + bodyVel * math.max(1 - math.abs(playerVelRaw.x) * 4, 0) + math.clamp(playerVel.x * 20, -2, 2)
   tail.rot[1].w = tail.rot[1].w * math.clamp(1 - playerVel.z - math.abs(bodyVel) * 0.02 + playerVel.y * 0.25 - inWater * 0.25, 0, 1)

   -- wag
   local targetWagSpeed = math.lerp(tail.config.idleSpeed, tail.config.walkSpeed, wagWalkSpeed)
   local targetWagStrength = math.lerp(tail.config.idleStrength, tail.config.walkStrength, wagWalkSpeed)
   for _, v in pairs(tail.config.enableWag) do
      if v then
         targetWagSpeed = tail.config.wagSpeed
         targetWagStrength = tail.config.wagStrength
         break
      end
   end
   tail.wagSpeed = math.lerp(tail.wagSpeed, targetWagSpeed, 0.15)
   tail.wagStrength = math.lerp(tail.wagStrength, targetWagStrength, 0.15)
   tail.wagTime = tail.wagTime + tail.wagSpeed * (1 - inWater * 0.25)
end

function events.tick()
   if not next(updatingTails) then return end
   -- get player velocity
   local bodyRot = player:getBodyYaw(1)
   local playerVelRaw = vectors.rotateAroundAxis(bodyRot, player:getVelocity(), vec(0, 1, 0))
   local bodyVel = (bodyRot - player:getBodyYaw(0) + 180) % 360 - 180
   -- body pitch
   local bodyPitch = 0
   local playerPose = player:getPose()
   local waterStrength = 1
   local wagWalkSpeed = 1
   if playerPose == "SWIMMING" then
      if #world.getBlockState(player:getPos()):getFluidTags() >= 1 then
         bodyPitch = -90 - player:getRot().x
      else
         bodyPitch = -90
      end
      waterStrength = 0.5
      -- inWater = inWater * 0.5
   elseif playerPose == "FALL_FLYING" or playerPose == "SPIN_ATTACK" then
      bodyPitch = -90 - player:getRot().x
      wagWalkSpeed = 0
   end
   playerVelRaw = vectors.rotateAroundAxis(bodyPitch, playerVelRaw, vec(1, 0, 0))
   -- update all tails
   for _, tail in pairs(updatingTails) do
      tickTail(tail, playerVelRaw, bodyVel, waterStrength, wagWalkSpeed)
   end
end

function events.render(delta)
   for _, tail in pairs(updatingTails) do
      local time = math.lerp(tail.oldWagTime, tail.wagTime, delta)
      local strength = math.lerp(tail.oldWagStrength, tail.wagStrength, delta)
      for i, v in pairs(tail.parts) do
         v:setRot(getPartRot(tail, i, delta, time, strength))
      end
   end
end

return tailPhysics
