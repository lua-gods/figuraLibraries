-- some extra stuff not related to library
vanilla_model.ALL:visible(false)
local eyeHeight, oldEyeHeight = 1.64, 1.64
function events.tick()
   oldEyeHeight = eyeHeight
   eyeHeight = math.lerp(eyeHeight, player:getEyeHeight(), 0.5)
end
function events.render(delta)
   local height = math.lerp(oldEyeHeight, eyeHeight, delta)
   nameplate.ENTITY:setPivot(0, height * 0.5 + 0.25, 0)
   renderer:setEyeOffset(player:getPermissionLevel() >= 2 and vec(0, -height * 0.5, 0) or nil)
   renderer:setOffsetCameraPivot(0, -height * 0.5, 0)
   
   models.model.root.head:setRot((vanilla_model.HEAD:getOriginRot() + 180) % 360 - 180)
end
-- library usage
local aurianims = require('aurianims')

local modelAnims = animations['model']

local animController = aurianims.new()

animController:setDriver(function(data)
   local velocity = player:getVelocity()

   data.velocity = velocity
   data.speed = velocity.xz:length()
   
   data.oldOnGround = data.onGround
   data.onGround = player:isOnGround()

   data.groundTime = data.onGround and data.groundTime + 1 or 0

   data.jumpTime = data.jumpTime * 0.85
   if not data.onGround and data.oldOnGround and velocity.y > 0.1 then
      data.jumpTime = math.min(velocity.y * 8, 2)
   elseif data.onGround then
      data.jumpTime = math.lerp(data.jumpTime, 0, 0.6)
   end
end, {
   onGround = true,
   jumpTime = 0,
   groundTime = 100
})

local walking = aurianims.mix(
   function(data, old)
      return math.lerp(old, data.speed * 4, 0.4)
   end,
   modelAnims.idle,
   aurianims.mix(
      function(data, old, anim1, anim2)
         anim1:speed(math.min(data.speed * 8, 2.5))
         anim2:speed(data.speed * 5)
         local run = data.speed > 0.24 and player:isOnGround()
         return math.lerp(old, run and 1 or 0, 0.4)
      end,
      modelAnims.walk,
      modelAnims.run
   )
)

animController:setTree(
   aurianims.stack{
      aurianims.mix(
         function (data, old)
            return math.lerp(
               old,
               math.min((data.onGround and 0 or data.jumpTime) + math.abs(data.velocity.y), 1),
               0.4
            )
         end,
         walking,
         aurianims.blend(
            function(data, old)
               return math.lerp(old, math.clamp(math.abs(data.velocity.y) * 5, 0, 1), 0.7) + 1
            end,
            aurianims.mix(
               function(data, old)
                  return math.lerp(old, math.clamp(data.velocity.y * 1.5 + 0.5, 0, 1), 0.4)
               end,
               modelAnims.moveDown,
               modelAnims.moveUp
            )
         )
      ),
      aurianims.blend(
         function(data)
            return data.groundTime > 1 and math.max(10 - data.groundTime, 0) or 0
         end,
         modelAnims.fall
      ),
      aurianims.blend(
         function(data)
            return data.jumpTime
         end,
         modelAnims.jump
      )
   }
)