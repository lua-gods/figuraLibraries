-- PixelLines - By AuriaFoxGirl ^^
-- https://github.com/lua-gods/figuraLibraries/tree/main/pixelLines/
local gridRes = 64

local lineWorld = models:newPart('pixelLineWorld', 'World')
local whitePixel = textures.whitePixel or textures:newTexture('whitePixel', 1, 1):setPixel(0, 0, 1, 1, 1)

---@class pixelLines
local mod = {}
---@class pixelLines.line
---@field pos1 Vector3
---@field pos2 Vector3
---@field Color Vector3|Vector4
---@field Depth number
---@field id number
local lineClass = {}
lineClass.__index = lineClass
local lines = {}
local forceUpdate = true
local oldCamPos = vec(0, 0, 0)
local oldCamRot = vec(0, 0, 0)
-- variables for optimization
local vec2Empty = vec(0, 0)
local lineScreenMin = vec(-2, -2)
local lineScrenMax = vec(2, 2)
local mathAbs = math.abs
local mathMax = math.max
local mathMin = math.min
local vectorsWorldToScreenSpace = vectors.worldToScreenSpace
local vectorsToCameraSpace = vectors.toCameraSpace

-- library
---creates new line
---@return pixelLines.line
function mod.new()
   local id = #lines + 1
   local obj = {
      pos1 = vec(0, 0, 0),
      pos2 = vec(0, 0, 0),
      Color = vec(1, 1, 1),
      Depth = 0,
      id = id
   }
   lines[id] = obj
   setmetatable(obj, lineClass)
   return obj
end

---sets resolution of lines
---higher resolutions will use more instructions
---@param res? number -- if nil will use default resolution
function mod.setResolution(res)
   gridRes = res or 64
end

---sets first position of line
---@param x Vector3|number
---@param y? number
---@param z? number
---@return self
function lineClass:setA(x, y, z)
   self.pos1 = y and vec(x, y, z) or x ---@diagnostic disable-line
   forceUpdate = true
   return self
end
lineClass.A = lineClass.setA

---sets second position of line
---@param x Vector3|number
---@param y? number
---@param z? number
---@return self
function lineClass:setB(x, y, z)
   self.pos2 = y and vec(x, y, z) or x ---@diagnostic disable-line
   forceUpdate = true
   return self
end
lineClass.B = lineClass.setB

---sets color of line
---@param r Vector3|Vector4|number
---@param g? number
---@param b? number
---@param a? number
---@return self
function lineClass:setColor(r, g, b, a)
   self.Color = g and vec(r, g, b, a) or r  ---@diagnostic disable-line
   forceUpdate = true
   return self
end
lineClass.color = lineClass.setColor

---sets depth of line in bb units (1 / 16 of block), will default to 0
---@param depth? number
---@return self
function lineClass:setDepth(depth)
   self.Depth = depth or 0
   forceUpdate = true
   return self
end
lineClass.depth = lineClass.setDepth

---Removes line from memory
function lineClass:free()
   lines[self.id] = nil
end

-- modified version of screen to world space made by GNamimates, used to get fov
local function screenToWorldSpace(distance, pos, fov)
   local mat = matrices.mat4()
   local rot = client:getCameraRot()
   local win_size = client:getWindowSize()
   local mpos = (pos / win_size - vec(0.5, 0.5)) * vec(win_size.x/win_size.y,1)
   if renderer:getCameraMatrix() then mat:multiply(renderer:getCameraMatrix()) end
   mat:translate(mpos.x*-fov*distance,mpos.y*-fov*distance,0)
   mat:rotate(rot.x, -rot.y, rot.z)
   mat:translate(client:getCameraPos())
   pos = (mat * vectors.vec4(0, 0, distance, 1)).xyz
   return pos
end

local function getRealFov()
   local fov = math.tan(math.rad(client.getFOV() / 2)) * 2
   local pos = vectors.worldToScreenSpace(screenToWorldSpace(1, vec(0, 0), fov)).xy
   local fovErr =  vec(-1, -1):length() / pos:length()
   return fov * fovErr
end

-- rendering
lineWorld.preRender = function()
   -- check if updating is needed
   local camPos = client.getCameraPos()
   local camRot = client.getCameraRot()
   if not forceUpdate and camPos == oldCamPos and camRot == oldCamRot then
      return
   end
   oldCamPos = camPos
   oldCamRot = camRot
   forceUpdate = false
   -- variables
   local windowSize = client.getScaledWindowSize()
   local fov = getRealFov()
   local aspectRatio = windowSize.x / windowSize.y
   -- decide resolution
   local textureSize = vec(gridRes, gridRes)
   if aspectRatio > 1 then
      textureSize.x = textureSize.x * aspectRatio
   else
      textureSize.y = textureSize.y / aspectRatio
   end
   -- extra variables
   local linePixelsLimit = gridRes * 3
   local textureSize2 = textureSize - 1
   local textureSize2Half = textureSize2 * 0.5
   local textureSizeHalf = textureSize * 0.5
   -- transform line world
   local mat = matrices.mat4()
   mat:translate(0, 0, -8)
   mat:scale(1 / textureSize.x * aspectRatio, 1 / textureSize.y, 1)
   mat:scale(fov, fov, 1)
   mat:rotate(camRot.x, -camRot.y, 0)
   mat:translate(camPos * 16)
   lineWorld:setMatrix(mat)
   -- render lines
   lineWorld:removeTask()
   local spriteI = 0
   -- draw lines
   for _, line in pairs(lines) do
      local pos1 = vectorsWorldToScreenSpace(line.pos1)
      local pos2 = vectorsWorldToScreenSpace(line.pos2)
      -- if pos1.z > 1 and pos2.z > 1 then -- skip lines behind camera
      if pos1.z > 1 and pos2.z > 1 and pos1.xy > lineScreenMin and pos2.xy > lineScreenMin and pos1.xy < lineScrenMax and pos2.xy < lineScrenMax then -- cull lines
         pos1.xy = (pos1.xy + 1) * textureSize2Half
         pos2.xy = (pos2.xy + 1) * textureSize2Half
         local color = line.Color
         local startPos = pos1.xy + 0.5
         local d = pos2 - pos1
         local step = mathMin(mathMax(mathAbs(d.x), mathAbs(d.y), 1), linePixelsLimit)
         local stepXY = d.xy / step
         local depth1 = vectorsToCameraSpace(line.pos1).z * 16 -- depth from worldToScreenSpace wont work here
         local depth2 = vectorsToCameraSpace(line.pos2).z * 16 -- thats why im using vectors.toCameraSpace for depth
         depth1 = mathMax(depth1 + line.Depth, 1)
         depth2 = mathMax(depth2 + line.Depth, 1)
         local depthMul = (depth2 - depth1) / step
         for i = 0, step do
            local pos = startPos + i * stepXY
            if pos >= vec2Empty and pos < textureSize then
               local depth = depth1 + i * depthMul
               spriteI = spriteI + 1
               lineWorld:newSprite(spriteI) ---@diagnostic disable-line: param-type-mismatch
                  :texture(whitePixel, 1, 1)
                  :renderType('EMISSIVE_SOLID')
                  :color(color)
                  :scale(depth)
                  :pos(((textureSizeHalf - pos:floor()) * depth):augmented(depth + 8))
            end
         end
      end
   end
end

return mod