-- note: this example avatar doesnt have second layer so if you want to use this as template you might need to add it yourself
-- hide vanilla model
vanilla_model.PLAYER:visible(false)
-- require library
local clothesLib = require('clothes')

-- list of modelparts, all modelparts need to be cube or mesh
-- modelparts will copied when defined in clothesGroups automatically
local clothesModelparts = {
   head = {
      models.model.Head.head,
   },
   body = {
      models.model.Body.body,
   },
   arms = {
      models.model.LeftArm.arm,
      models.model.RightArm.arm,
   },
   legs = {
      models.model.LeftLeg.leg,
      models.model.RightLeg.leg,
   },
}

-- list of clothes groups (categories), every group can have 1 cloth enabled, groups can be colored
local clothesGroups = {
   {
      title = 'top', -- name of group
      -- texture where every region of skin texture size will be 1 cloth
      -- cloths start from top left corner in texture and go right until edge then they return to the left and move down
      -- while textures dont need to be applied to any modelpart, you need to include them in any blockbench model for figura to find them
      texture = textures['top'],
      models = {'body', 'arms', 'legs'}, -- here you specify which models from modelparts list will be used for this cloth group
      distance = 0.05, -- distance from orginal model, works similiar to inflating cube in blockbench, do not set this value too high or it might look weird
      limit = 3, -- not used by library but is used for action wheel code below, note: there is hard limit of 255 clothes per group that can't be avoided because of how clothes are compressed during ping
      names = {'t-shirt', 'shirt', 'off shoulder thing'}
   },
   { -- the values do same thing here as in previous group
      title = 'pants',
      texture = textures['bottom'],
      models = {'legs', 'body'},
      distance = 0.025,
      limit = 2,
      names = {'pants', 'shorts'}
   },
   -- you can add more clothes groups
}

local clothes = clothesLib.new(
   'clothes', -- name, if your using this library multiple times in your avatar make sure its unique
   vec(64, 64), -- texture size of skin, in my case its 64x64
   clothesModelparts, -- list of modelparts
   clothesGroups, -- list of groups/categories
   { -- optional default outfit, will be applied at init
      -- key - title of cloth group
      -- value - cloth from group (first number), color in rgb from 0 to 1 (last 3 numbers)
      top = vec(3, 1, 0.7, 0.85),
      pants = vec(2, 0.22, 0.2, 0.25)
   },
   'clothes' -- optional name for config, if specificed clothes will be saved
)

-- sync clothes every 10 seconds to make sure even new players see changed clothes
-- clothes lib have fancy clothes compression to turn make pinged data take less space
function pings.clothesSync(data)
   clothes:setFromCompressedOutfit(data, true)
end
local clothesSyncTime = 0
function events.tick()
   clothesSyncTime = clothesSyncTime + 1
   if clothesSyncTime > 10 * 20 then -- 10 seconds * 20 ticks
      clothesSyncTime = 0
      pings.clothesSync(clothes:compressOutfit())
   end
end

-- action wheel
if not host:isHost() then return end

local colors = {
   '#ff7b7e',
   '#ff8900',
   '#ffcb00',
   '#bbe83d',
   '#a8d9ff',
   '#e09dff',
   '#ff99ce',
   '#ffffff',
   '#2e2a38',
}

local page = action_wheel:newPage()
action_wheel:setPage(page)

-- loop through all groups
for _, group in pairs(clothesGroups) do
   local action = page:newAction()
   action:setItem('minecraft:leather_chestplate')

   local function updateActionTitle()
      local id, color = clothes:getCloth(group.title)
      local colorHex = '#'..vectors.rgbToHex(color)
      local json = {
         group.title,
         '\n\n',
         "color: ",
         {text = colorHex, color = colorHex},
         '\n'
      }
      for i = 0, #group.names do
         local name = group.names[i]
         if i == 0 then
            name = 'none'
         end
         table.insert(json, '\n')
         if i == id then
            table.insert(json, {
               text = '> '..name,
            })
         else
            table.insert(json, {
               text = '  '..name,
               color = 'gray'
            })
         end
      end
      action:setTitle(toJson(json))
   end
   updateActionTitle()

   action:onLeftClick(function()
      local id = clothes:getCloth(group.title)
      id = (id + 1) % (group.limit + 1)

      clothes:setCloth(group.title, id)
      updateActionTitle()
   end)

   local currentColor = 0
   action:onScroll(function(dir)
      currentColor = (currentColor + dir) % #colors
      local color = vectors.hexToRGB(colors[math.round(currentColor) + 1])
      clothes:setCloth(group.title, nil, color)
      updateActionTitle()
   end)
end