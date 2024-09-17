# particle model
Simple figura script to turn models to particles

## example usage
```lua
local particleModel = require('particle_model')

local key = keybinds:newKeybind('', 'key.keyboard.g')
key.press = function()
   particleModel.render(
      models
   )
   models:visible(false)
end

key.release = function()
   models:visible(true)
end
```
