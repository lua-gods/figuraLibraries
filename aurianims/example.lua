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
   aurianims.blend(
      function(data, old, anim1, anim2)
         return math.lerp(old, data.speed * 4, 0.4)
      end,
      modelAnims.idle,
      aurianims.blend(
         function(data, old)
            local t = math.clamp((data.speed - 0.22) * 16, 0, 1)
            return math.lerp(old, t, 0.4)
         end,
         modelAnims.walk,
         modelAnims.run
      )
   )
)