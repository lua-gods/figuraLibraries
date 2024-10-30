# Aurianims
Library to smoothly control multiple amimations

## Usage

Require library
```lua
local aurianims = require('aurianims')
```

Create animation controller that will control animations
```lua
local controller = aurianims.new()
```

Set tree of animation nodes for example: 
```lua
animController:setTree(
   aurianims.mix(
      function(data, old)
         return math.lerp(
            old,
            math.clamp(player:getVelocity().xz:length(), 0, 1),
            0.4
         )
      end,
      animations.model.idle,
      animations.model.walk,
   )
)
```

animation nodes are groups of animations or more nodes, they also control how animations should mix

- `mix` Will mix between 2 nodes/animations using a given function where returning 0 will only play first animation, returning 1 will only play second animation, returning 0.5 will play both of them at 50% strength
- `stack` will combine nodes/animations into 1
- `blend` will control strength of animation/node

You can also optionally set driver which will allow to set variables that can be used in nodes for example:
```lua
animController:setDriver(function(data)
   local velocity = player:getVelocity()
   data.speed = velocity.xz:length()
end)

animController:setTree(
   aurianims.mix(
      function(data, old)
         return math.lerp(
            old,
            math.clamp(data.speed, 0, 1),
            0.4
         )
      end,
      animations.model.idle,
      aurianims.mix(
         function(data, old)
            local run = data.speed > 0.24
            return math.lerp(old, run and 1 or 0, 0.4)
         end
         animations.model.walk,
         animations.model.run
      )
   )
)
```

You can also check out the `example.lua` for example or download this repository to try out example avatar