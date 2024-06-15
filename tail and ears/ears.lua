local earsPhysics = {} -- made by Auriafoxgirl
---@class auria.earsPhysics
---@field config table
---@field model ModelPart
local ears = {}
local updatingEars = {}
ears.__index = ears
local oldPlayerRot

---creates new ears physics
---@param leftEar ModelPart|[ModelPart]
---@param rightEar ModelPart|[ModelPart]
function earsPhysics.new(leftEar, rightEar)
   local obj = setmetatable({}, ears)
   obj.config = { -- default config
      velocityStrength = 1, -- velocity strength
      extraAngle = 15, -- rotates ears by this angle when crouching
      useExtraAngle = {}, -- if any of variables in this table is true extraAngle will be used even when not crouching
      addAngle = {}, -- adds angle to ear rotation
   }
   -- model
   obj.leftEar = leftEar
   obj.rightEar = rightEar
   obj.defaultLeftEarRot = leftEar:getRot()
   obj.defaultRightEarRot = rightEar:getRot()
   -- other
   obj.rot = vec(0, 0, 0, 0)
   obj.oldRot = obj.rot
   obj.vel = vec(0, 0, 0, 0)
   -- finish
   updatingEars[obj] = obj
   return obj
end

---merge new config with current config, returns self for chaining
---@param tbl table
---@return self
function ears:setConfig(tbl)
   for i, v in pairs(tbl) do
      self.config[i] = v
   end
   return self
end

---set if ears should update, returns self for chaining
---@param x boolean
---@return self
function ears:setUpdate(x)
   updatingEars[self] = x and self or nil
   return self
end

---remove ears physics from ears
function ears:remove()
   updatingEars[self] = nil
end

local function tickEars(ears, playerVel, playerRotVel, isCrouching)
   -- set oldRot
   ears.oldRot = ears.rot
   -- set target rotation
   local targetRot = 0
   if isCrouching then
      targetRot = ears.config.extraAngle
   else
      for _, v in pairs(ears.config.useExtraAngle) do
         if v then
            targetRot = ears.config.extraAngle
            break
         end
      end
   end
   for _, v in pairs(ears.config.addAngle) do
      targetRot = targetRot + v
   end
   -- player velocity
   playerVel = playerVel * ears.config.velocityStrength * 40
   playerRotVel = playerRotVel * ears.config.velocityStrength
   -- update velocity and rotation
   ears.vel = ears.vel * 0.6 + (vec(0, 0, 0, targetRot) - ears.rot) * 0.2
   ears.rot = ears.rot + ears.vel
   ears.rot.x = ears.rot.x + math.clamp(playerVel.z + playerRotVel.x, -14, 14)
   ears.rot.z = ears.rot.z + math.clamp(-playerVel.x, -6, 6)
   ears.rot.w = ears.rot.w + math.clamp(playerVel.y * 0.25, -4, 4)
end

function events.tick()
   if not next(updatingEars) then return end
   -- velocity and stuff
   local playerRot = player:getRot()
   if not oldPlayerRot then
      oldPlayerRot = playerRot
   end
   local playerRotVel = (playerRot - oldPlayerRot) * 0.75
   oldPlayerRot = playerRot
   local playerVel = player:getVelocity()
   playerVel = vectors.rotateAroundAxis(playerRot.y, playerVel, vec(0, 1, 0))
   playerVel = vectors.rotateAroundAxis(-playerRot.x, playerVel, vec(1, 0, 0))
   local isCrouching = player:getPose() == "CROUCHING"
   -- update ears
   for _, ears in pairs(updatingEars) do
      tickEars(ears, playerVel, playerRotVel, isCrouching)
   end
end

function events.render(delta)
   for _, ears in pairs(updatingEars) do
      local currentRot = math.lerp(ears.oldRot, ears.rot, delta)
      ears.leftEar:setRot(ears.defaultLeftEarRot + currentRot.xyz + currentRot.__w)
      ears.rightEar:setRot(ears.defaultRightEarRot + currentRot.x_z - currentRot._yw)
   end
end

return earsPhysics
