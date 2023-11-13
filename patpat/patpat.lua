-- config
local config = {
   patParticle = "minecraft:heart", -- particle that will be used when patting
   patpatKey = "key.mouse.right", -- keybind that will be used for patpat

   requireEmptyOffHand = false,
   patDelay = 3, -- delay between pats when holding patpat key in ticks
   holdFor = 6, -- amount of ticks before patting stops, if this value is smaller than patDelay it might cause issues

   patpatBlocks = { -- list of blocks that can be patted 
      "minecraft:player_head", "minecraft:player_wall_head"
   },
   disabledEntities = { -- list of entites that will be ignored when trying to pat them
      "minecraft:boat", "minecraft:chest_boat", "minecraft:minecart", "minecraft:area_effect_cloud", "minecraft:interaction"
   },

   noPats = false,
   noHearts = false,
}

-- events
local playerEvents = { -- list of tables containing functions that get called when specific thing happens
   onPat = { -- runs when you start being petted
      function() end
   },
   onUnpat = { -- runs when you stop being petted
      function() end
   },
   togglePat = { -- runs when you start or stop being petted, isPetted - boolean that is true when someone starts
      function(isPetted) end
   },
   whilePat = { -- runs every tick while being patted, patters - list of people patting you 
      function(patters) end
   },
   oncePat = { -- every time someone pats you, entity - entity that is petting you
      function(entity) end
   },
}

local headEvents = { -- this table works like playerEvents table but instead of player its for player heads and every event have extra argument that is position of player head
   onPat = {},
   onUnpat = {},
   togglePat = {},
   whilePat = {},
   oncePat = {},
}

-- events handler
local eventsList = {player = playerEvents, head = headEvents}
setmetatable(eventsList, {__index = playerEvents})

local function callEvent(group, eventName, ...)
   for _, func in ipairs(eventsList[group][eventName]) do
      func(...)
   end
end

local myPatters = {player = {}, head = {}}

function events.tick()
   local patted = false
   for uuid, time in pairs(myPatters.player) do
      if time <= 0 then
         callEvent("player", "onUnpat")
         callEvent("player", "togglePat", false)
         myPatters.player[uuid] = nil
      else
         myPatters.player[uuid] = time - 1
         patted = true
      end
   end
   if patted then
      callEvent("player", "whilePat", myPatters.player)
   end
   for i, headPatters in pairs(myPatters.head) do
      patted = false
      local pos = headPatters.pos
      for uuid, time in pairs(headPatters.list) do
         if time <= 0 then
            callEvent("head", "onUnpat", pos)
            callEvent("head", "togglePat", false, pos)
            headPatters.list[uuid] = nil
         else
            headPatters.list[uuid] = time - 1
            patted = true
         end
      end
      if patted then
         callEvent("head", "whilePat", headPatters.list, pos)
      else
         myPatters.head[i] = nil
      end
   end
end

avatar:store("petpet", function(uuid, time)
   time = math.min(time or config.holdFor, 100)
   if not myPatters.player[uuid] then
      callEvent("player", "onPat")
      callEvent("player", "togglePat", true)
   end
   myPatters.player[uuid] = time
   local entity = world.getEntity(uuid)
   if entity then
      callEvent("player", "oncePat", entity)
   end
end)

avatar:store("petpet.playerHead", function(uuid, time, x, y, z)
   if not x or not y or not z then
      return
   end
   time = math.min(time or config.holdFor, 100)
   local pos = vec(x, y, z)
   local i = tostring(pos)
   local patters = myPatters.head[i]
   if not patters then
      patters = {}
      myPatters.head[i] = {list = patters, pos = pos}
   end

   if not patters[uuid] then
      callEvent("head", "onPat", pos)
      callEvent("head", "togglePat", true, pos)
   end
   patters[uuid] = time
   local entity = world.getEntity(uuid)
   if entity then
      callEvent("head", "oncePat", entity, pos)
   end
end)

-- update config
if config.noPats then
   avatar:store("patpat.noPats", true)
end
if config.noHearts then
   avatar:store("patpat.noHearts", true)
end

-- useful variables and functions
local myUuid = avatar:getUUID()

local function packUuid(uuid)
   uuid = uuid:gsub("-", "")
   local newUuid = ""
   for i = 1, 32, 2 do
      newUuid = newUuid..string.char(tonumber(uuid:sub(i, i + 1), 16))
   end
   return newUuid
end

local uuidDashes = {[4] = true, [6] = true, [8] = true, [10] = true}
local function unpackUuid(uuid)
   local newUuid = ""
   for i = 1, 16 do
      newUuid = newUuid..string.format("%02x", string.byte(uuid:sub(i, i)))
      if uuidDashes[i] then
         newUuid = newUuid.."-"
      end
   end
   return newUuid
end

local function getAvatarVarsFromBlock(block)
   if block.id == "minecraft:player_head" or block.id == "minecraft:player_wall_head" then
      local entityData = block:getEntityData()
      if entityData then
         local skullOwner = entityData.SkullOwner and entityData.SkullOwner.Id and client.intUUIDToString(table.unpack(entityData.SkullOwner.Id))
         if skullOwner then
            return world.avatarVars()[skullOwner] or {}
         end
      end
   end
   return {}
end

-- pings
function pings.patpat(a, b, c)
   if not player:isLoaded() then
      return
   end
   local particlePos
   if b then -- block
      local pos = vec(a, b, c)
      local block = world.getBlockState(pos)

      local blockAvatarVars = getAvatarVarsFromBlock(block)
      if not blockAvatarVars["patpat.noHearts"] then
         particlePos = pos + vec(
            math.random() * 0.8 + 0.1,
            math.random() * 0.8,
            math.random() * 0.8 + 0.1
         )
      end

      pcall(blockAvatarVars["petpet.playerHead"], myUuid, config.holdFor, pos.x, pos.y, pos.z)
   else -- entity
      local entity = world.getEntity(unpackUuid(a))

      if not entity then
         return
      end
      if entity:getType() == "minecraft:player" and entity:getVariable("patpat.noPats") then
         return
      end

      local entityPos = entity:getPos()
      local boundingBox = entity:getBoundingBox()
      particlePos = entityPos + vec(
         (math.random() - 0.5) * boundingBox.x,
         math.random() * boundingBox.y,
         (math.random() - 0.5) * boundingBox.z
      )

      pcall(entity:getVariable("petpet"), myUuid, config.holdFor)
   end

   if particlePos then
      particles[config.patParticle]:pos(particlePos):size(1):spawn()
   end
end

-- host only
if not host:isHost() then
   return eventsList
end

-- update config
for i, v in ipairs(config.patpatBlocks) do
   config.patpatBlocks[v] = i
end

for i, v in ipairs(config.disabledEntities) do
   config.disabledEntities[v] = i
end

-- code
local function patPat()
   if player:getItem(1).id ~= "minecraft:air" then
      return
   end
   if config.requireEmptyOffHand and player:getItem(2).id ~= "minecraft:air" then
      return
   end

   local myPos = player:getPos():add(0, player:getEyeHeight(), 0)
   local eyeOffset = renderer:getEyeOffset()
   if eyeOffset then
      myPos = myPos + eyeOffset
   end

   local block, blockPos = player:getTargetedBlock(true, 5)
   local dist = (myPos - blockPos):length()
   local targetType = "block"
   
   local entity, entityPos = player:getTargetedEntity(5)
   if entity then
      local newDist = (myPos - entityPos):length()
      if newDist < dist then
         targetType = "entity"
      end
   end

   if targetType == "block" then
      if not config.patpatBlocks[block.id] then
         return
      end

      if getAvatarVarsFromBlock(block)["patpat.noPats"] then
         return
      end

      pings.patpat(block:getPos():unpack())
   else
      local entityType = entity:getType()
      if config.disabledEntities[entityType] then
         return
      end
      if entityType == "minecraft:player" then
         if entity:getVariable("patpat.noPats") then
            return
         end
      end

      pings.patpat(packUuid(entity:getUUID()))
   end
   host:swingArm()
end

local patting = false
local patTime = 0
local key = keybinds:newKeybind("patpat", config.patpatKey)

key.press = function() if not host:getScreen() and not action_wheel:isEnabled() and player:isLoaded() and player:isSneaking() then patting = true patPat() end end
key.release = function() patting = false patTime = 0 end

function events.tick()
   if not patting then
      return
   end

   patTime = patTime + 1
   if patTime % 3 == 0 then
      patPat()
   end
end

-- return, made by Auria
return eventsList
