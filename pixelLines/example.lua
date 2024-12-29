local lineLib = require('pixelLines')
-- local lines = require('pixelLines')

local offset = vec(-230, 63, 143) - client.getViewer():getPos()

local line = lineLib:new()
   :setA(vec(-234, 65, 144) - offset)
   :setB(vec(-233, 64, 143) - offset)
   :setColor(1, 1, 1)
   :setColor(1, 1, 1, 1)
   :setColor(vec(1, 1, 1))
   :color(vec(1, 1, 1, 1))
   :setDepth()
   :depth(0)
   -- :setColor(1, 1, 1)

function events.tick()
   if player:isSneaking() then
      line:setColor(vectors.hsvToRGB((world.getTime() * 0.01) % 1, 0.5, 1))
   end
end

do
   local a = vec(-243, 69, 134) - offset
   local b = vec(-223, 63, 136) - offset
   local c = a
   local k = 0.05
   for t = k, 1, k do
      local d = math.lerp(a, b, t)
      lineLib:new()
         :A(c)
         :B(d)
         :color(1, 0.6, 0.8)
         :depth()
      c = d
   end
end

do
   local whitePixel = textures.whitePixel or textures:newTexture('whitePixel', 1, 1):setPixel(0, 0, 1, 1, 1)
   models:newPart('', 'World'):newSprite(''):pos(vec(-231, 64.1, 144) * 16 - offset * 16):texture(whitePixel, 32, 18):renderType('emissive_solid'):color(0.8, 0.8, 0.85)
   models:newPart('', 'World'):newSprite(''):pos(vec(-231, 64.1, 146) * 16 - offset * 16):texture(whitePixel, 32, 18):renderType('emissive_solid'):color(0.7, 0.7, 0.75):rot(0, -90, 0)
   models:newPart('', 'World'):newSprite(''):pos(vec(-231, 64.1, 146) * 16 - offset * 16):texture(whitePixel, 32, 32):renderType('emissive_solid'):color(0.95, 0.95, 0.98):rot(90, 0, 0)
   lineLib:new():A(vec(-231, 64.1, 144) - offset):B(vec(-231, 63, 144) - offset):color(0.8, 0.8, 0.85):depth(-8)
   lineLib:new():A(vec(-231, 64.1, 144) - offset):B(vec(-233, 64.1, 144) - offset):color(0.8, 0.8, 0.85):depth(-8)
   lineLib:new():A(vec(-231, 64.1, 144) - offset):B(vec(-231, 64.1, 146) - offset):color(0.7, 0.7, 0.75):depth(-8)
end