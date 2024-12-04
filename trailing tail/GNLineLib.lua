--[[______   __
  / ____/ | / / By: GNamimates
 / / __/  |/ / GNlineLib v2.0.1
/ /_/ / /|  / Allows you to draw lines in the world at ease.
\____/_/ |_/ https://github.com/lua-gods/GNs-Avatar-2/tree/main/libraries/GNlineLib.lua]]

local default_model = models:newPart("gnlinelibline","WORLD"):scale(16,16,16)
local default_texture = textures["1x1white"] or textures:newTexture("1x1white",1,1):setPixel(0,0,vectors.vec3(1,1,1))
local lines = {} ---@type line[]
local queue_update = {} ---@type line[]

local cpos = client:getCameraPos()

---@overload fun(pos : Vector3)
---@param x number
---@param y number
---@param z number
---@return Vector3
local function figureOutVec3(x,y,z)
   local typa = type(x)
   if typa == "Vector3" then
      return x:copy()
   elseif typa == "number" then
      return vectors.vec3(x,y,z)
   end
end

---@class line # A straight path from point A to B
---@field id integer
---@field visible boolean
---@field a Vector3? # First end of the line
---@field b Vector3? # Second end of the line
---@field dir Vector3? # The difference between the first and second ends position
---@field dir_override Vector3? # Overrides the dir of the line, useful for non world parent parts
---@field length number # The distance between the first and second ends
---@field width number # The width of the line in meters
---@field color Vector4 # The color of the line in RGBA
---@field depth number # The offset depth of the line. 0 is normal, 0.5 is farther and -0.5 is closer
---@field package _queue_update boolean # Whether or not the line should be updated in the next frame
---@field model SpriteTask
local line = {}
line.__index = line
line.__type = "gn.line"
line.__type = "gn.line"

---Creates a new line.
---@param preset line?
---@return line
function line.new(preset)
   preset = preset or {}
   local next_free = #lines+1 
   local new = setmetatable({},line)
   new.visible = true
   new.a = preset.a or vectors.vec3()
   new.b = preset.b or vectors.vec3()
   new.width = preset.width or 0.125
   new.width = preset.width or 0.125
   new.color = preset.color or vectors.vec3(1,1,1)
   new.depth = preset.depth or 1
   new.model = default_model:newSprite("line"..next_free):setTexture(default_texture,1,1):setRenderType("EMISSIVE_SOLID"):setScale(0,0,0)
   new.id = next_free
   lines[next_free] = new
   return new
end

---Sets both points of the line.
---@overload fun(self : line, from : Vector3, to :Vector3): line
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return line
function line:setAB(x1,y1,z1,x2,y2,z2)
   if type(x1) == "Vector3" and type(y1) == "Vector3" then
      self.a = x1:copy()
      self.b = y1:copy()
      self.a = x1:copy()
      self.b = y1:copy()
   else
      self.a = vectors.vec3(x1,y1,z1)
      self.b = vectors.vec3(x2,y2,z2)
      self.a = vectors.vec3(x1,y1,z1)
      self.b = vectors.vec3(x2,y2,z2)
   end
   self:update()
   self:update()
   return self
end

---Sets the first point of the line.
---@overload fun(self: line ,pos : Vector3): line
---@param x number
---@param y number
---@param z number
---@return line
function line:setA(x,y,z)
   self.a = figureOutVec3(x,y,z)
   self:update()
   return self
end

---Sets the second point of the line.
---@overload fun(self: line ,pos : Vector3): line
---@param x number
---@param y number
---@param z number
---@return line
function line:setB(x,y,z)
   self.b = figureOutVec3(x,y,z)
   self:update()
   return self
end

---Sets the width of the line.  
---Note: This is in minecraft blocks/meters.
---@param w number
---@return line
function line:setWidth(w)
   self.width = w
   self:update()
   return self
end

---Sets the render type of the line.  
---by default this is "CUTOUT_EMISSIVE_SOLID".
---@param render_type ModelPart.renderType
---@return line
function line:setRenderType(render_type)
   self.model:setRenderType(render_type)
   return self
end

---Sets the color of the line.
---@overload fun(self : line, rgb : Vector3): line
---@overload fun(self : line, rgb : Vector4): line
---@overload fun(self : line, string : string): line
---@param r number
---@param g number
---@param b number
---@param a number
---@return line
function line:setColor(r,g,b,a)
   local rt,yt,bt = type(r),type(g),type(b)
   if rt == "number" and yt == "number" and bt == "number" then
      self.color = vectors.vec4(r,g,b,a or 1)
   elseif rt == "Vector3" then
      self.color = r:augmented()
   elseif rt == "Vector4" then
      self.color = r
   elseif rt == "string" and rt:find("#%x%x%x%x%x%x") then
      self.color = vectors.hexToRGB(r):augmented(1)
   else
      error("Invalid Color parameter, expected Vector3, (number, number, number) or Hexcode, instead got ("..rt..", "..yt..", "..bt..")")
   end
   self.model:setColor(self.color)
   return self
end

---Sets the depth of the line.  
---Note: this is an offset to the depth of the object. meaning 0 is normal, `0.5` is farther and `-0.5` is closer
---@param z number
---@return line
function line:setDepth(z)
   self.depth = 1 + z
   return self
end

---Frees the line from memory.
function line:free()
   lines[self.id] = nil
   self.model:remove()
   self._queue_update = false
   self = nil
end

---@param visible boolean
---@return line
function line:setVisible(visible)
   self.visible = visible
   self.model:setVisible(visible)
   if visible then
      self:immediateUpdate()
   end
   return self
end

---Queues itself to be updated in the next frame.
---@return line
function line:update()
   if not self._queue_update and self.visible then
      queue_update[#queue_update+1] = self
      self._queue_update = true
   end
   return self
end

---Immediately updates the line without queuing it.
---@return line
function line:immediateUpdate()
   local a,b = self.a,self.b
   local offset = a - cpos
   local dir = (b - a)
   self.dir = dir
   local l = dir:length()
   self.length = l
   local w = self.width
   local d = dir:normalized()
   local p = (offset - d * offset:copy():dot(d)):normalize()
   local c = p:copy():cross(d) * w
   local mat = matrices.mat4(
      (p:cross(d) * w):augmented(0),
      (-d * (l + w * 0.5)):augmented(0),
      p:augmented(0),
      (a + c * 0.5):augmented(1)
   )
   self.model:setMatrix(mat * self.depth)
   return self
end

events.WORLD_RENDER:register(function ()
   local c = client:getCameraPos()
   if c ~= cpos then
      cpos = c
      for _, l in pairs(lines) do
         l:update()
      end
   end
   for i = 1, #queue_update, 1 do
      local l = queue_update[i]
      if l._queue_update then
         l:immediateUpdate()
         l._queue_update = false
      end
   end
   queue_update = {}
end)

return {
   new = line.new,
   default_model = default_model,
   default_texture = default_texture,
   _VERSION = "2.0.1"
}