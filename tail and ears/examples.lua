-- single tail
local tailPhysics = require('tail')

local tail = tailPhysics.new(models.example.Body.tail)

-- changing config default config is in tail.lua (optional)
tail:setConfig {
   idleSpeed = vec(0.025, 0.05, 0), -- how fast should tail move when nothing is happening
   idleStrength = vec(1, 3, 0), -- how much should tail move
}

-- tail wag when pressing keybind (optional)
keybinds:newKeybind("tail - wag", "key.keyboard.v")
   :onPress(function() pings.tailWag(true) end)
   :onRelease(function() pings.tailWag(false) end)

function pings.tailWag(x)
   tail.config.enableWag.keybind = x
end

-- multiple tails example (tail2, tail3 not in example)
--[[
local tailPhysics = require('tail')

local tail = tailPhysics.new(models.example.Body.tail)
local tail2 = tailPhysics.new(models.example.Body.tail6)
local tail3 = tailPhysics.new(models.example.Body.tail11)

keybinds:newKeybind("tail - wag", "key.keyboard.v")
   :onPress(function() pings.tailWag(true) end)
   :onRelease(function() pings.tailWag(false) end)

function pings.tailWag(x)
   tail.config.enableWag.keybind = x
   tail2.config.enableWag.keybind = x
   tail3.config.enableWag.keybind = x
end
--]]
-- ears
local earsPhysics = require('ears')

local ears = earsPhysics.new(models.example.Head.leftEar, models.example.Head.rightEar)
ears:setConfig {
  -- you can check ears.lua to see default config
}
