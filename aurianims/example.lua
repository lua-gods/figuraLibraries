-- some extra stuff not related to library
vanilla_model.ALL:visible(false)
function events.render()
   models.model.root.head:setRot((vanilla_model.HEAD:getOriginRot() + 180) % 360 - 180)
end
-- library usage
local aurianims = require('aurianims')

local modelAnims = animations['model']

local controller = aurianims.new()

controller:setData(function(new, old)
   new.speed = player:getVelocity().xz:length()
end)

controller:setTree(
   aurianims.mix(
      function(data, old)
         return math.lerp(old, data.speed * 4, 0.4)
      end,
      modelAnims.idle,
      aurianims.mix(
         function(data, old, anim1, anim2)
            anim1:speed(math.min(data.speed * 8, 2.5))
            anim2:speed(data.speed * 5)
            local run = data.speed > 0.24 and (player:isOnGround() or data.speed < 0.35)
            return math.lerp(old, run and 1 or 0, 0.4)
         end,
         modelAnims.walk,
         modelAnims.run
      )
   )
)