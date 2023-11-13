# GNTweenLibrary
* Helps you smoothly transition Numbers and Vectors.
  
# How to Use
the library adds a while batch of transition functions, but this one uses them all for ease of use:
```lua
GNTweenLib.tweenFunction(
   from : VectorN|number, -- both from and to must have the same value type
   to : VectorN|number, -- numbers and vectors
   duration : number, -- in seconds
   ease : easeType, -- ease transition type, automatically annotated in VScode
   tick : fun(transition : value, time : number), -- gets called every frame when transitioning
   on_finish : function?, -- gets called every frame when transitioning
   unique_name : string?) -- optional value
```
# Example Code
```lua
local tween = require("GNTweenLib")

tween.tweenFunction(vectors.vec3(i,0,0),vectors.vec3(i,4,0),2,"inOutBounce",function (p)
   cube:setPos(p*16)
end)
```
this is a snippet from the avatar in the GIF

# All transition types (easeType)
```
linear
inQuad    outQuad    inOutQuad    outInQuad
inCubic   outCubic   inOutCubic   outInCubic
inQuart   outQuart   inOutQuart   outInQuart
inQuint   outQuint   inOutQuint   outInQuint
inSine    outSine    inOutSine    outInSine
inExpo    outExpo    inOutExpo    outInExpo
inCirc    outCirc    inOutCirc    outInCirc
inElastic outElastic inOutElastic outInElastic
inBack    outBack    inOutBack    outInBack
inBounce  outBounce  inOutBounce  outInBounce
```