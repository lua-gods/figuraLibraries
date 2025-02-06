-- Clothes Lib - By AuriaFoxGirl ^^
-- https://github.com/lua-gods/figuraLibraries/tree/main/clothes/
---@class auria.clothes
local lib = {}
---@class auria.clothes.Handler
---@field groups table
---@field current {[string]: Vector4}
---@field currentCompressed string
---@field configName string?
---@field ping function
---@field outfitOverride {[any]: {[string]: Vector4}} -- if outfit exists in this table it will be used instead of selected clothes e.g. could be used to change outfit while in water, remember to update clothes after changing it
local clothesHandler = {}
clothesHandler.__index = clothesHandler
local emptyVec3 = vec(0, 0, 0)

---@overload fun(tbl: table): table
local function copyOutfit(tbl)
   local t = {}
   for i, v in pairs(tbl) do
      t[i] = v:copy()
   end
   return t
end

---creates new clothes handler
---@param name string -- used in pings
---@param textureSize Vector2
---@param modelpartsList {[string]: ModelPart[]|{[number]: ModelPart, uvSize: Vector2?, addToParent: boolean?}} -- modelparts used for clothes layers should be cube or mesh
---@param groups {title: string, texture?: Texture, models: string[], distance: number, modelparts: ModelPart[], enableModels?: {[number]: {[1]: ModelPart, [2]: Vector2}}}[]
---@param defaultOutfit? {[string]: Vector4}
---@param configName? string -- if provided the clothes will be stored in config with this name
---@return auria.clothes.Handler
function lib.new(name, textureSize, modelpartsList, groups, defaultOutfit, configName)
   local obj = {
      name = name,
      groups = groups,
      textureSize = textureSize,
      configName = configName,
      outfitOverride = {},
      toggableModels = {},
      renderedClothes = '',
      current = nil,
      currentCompressed = nil,
      ping = nil,
   }
   setmetatable(obj, clothesHandler)
   if configName then
      obj.current = config:load(configName)
   end
   if type(obj.current) ~= 'table' then
      obj.current = copyOutfit(defaultOutfit)
   end
   for _, v in pairs(groups) do
      if not obj.current[v.title] then
         obj.current[v.title] = vec(0, 1, 1, 1)
      end
   end
   obj.currentCompressed = obj:compressOutfit()
   -- pings
   local pingName = "auria.clothes."..name
   pings[pingName] = function(data) obj:setFromCompressedOutfit(data) end
   obj.ping = pings[pingName]
   -- create data for modelparts
   local modelpartsData = {}
   for i, group in pairs(groups) do
      group.modelparts = {}
      group.textureSize = group.texture and group.texture:getDimensions() or vec(16, 16) 
      group.clothesLimitX = group.textureSize.x / textureSize.x
      group.uvScale = (textureSize / group.textureSize):augmented()
      for _, v in pairs(group.models or {}) do
         if not modelpartsData[v] then
            modelpartsData[v] = {}
         end
         table.insert(modelpartsData[v], i)
      end
      if group.enableModels then
         for _, modelData in pairs(group.enableModels) do
            local model = modelData[1]
            obj.toggableModels[model] = modelpartsList[model]
         end
      end
   end
   -- generate modelparts
   for i, groupsInfo in pairs(modelpartsData) do
      local modelparts = modelpartsList[i]
      for _, model in ipairs(modelparts) do
         local expandDirs = {}
         for _, vertexGroup in pairs(model:getAllVertices()) do
            for _, vertex in pairs(vertexGroup) do
               local id = tostring(vertex:getPos())
               expandDirs[id] = (expandDirs[id] or emptyVec3) + vertex:getNormal()
            end
         end
         local modelsGroup = model:newPart('clothes_'..model:getName()):remove()
         for _, v in pairs(groupsInfo) do
            local group = groups[v]
            local newModel = model:copy('')
               :visible(false)
               :setPrimaryTexture('CUSTOM', group.texture)
               :setSecondaryRenderType('NONE')
            table.insert(group.modelparts, newModel)
            modelsGroup:addChild(newModel)
            local dist = group.distance
            for _, vertexGroup in pairs(newModel:getAllVertices()) do
               for _, vertex in pairs(vertexGroup) do
                  local pos = vertex:getPos()
                  vertex:setPos(pos + expandDirs[tostring(pos)] * dist)
               end
            end
         end
         if modelparts.addToParent then
            model:getParent():addChild(modelsGroup)
         else
            model:addChild(modelsGroup)
         end
      end
   end
   -- update
   if configName or defaultOutfit then
      obj:update()
   end
   -- return
   return obj
end

---updates clothes, returns self for chaining
---@param self self
---@param ignoreChangeFunc? boolean -- if true clothes change function will be ignored
function clothesHandler:update(ignoreChangeFunc)
   local outfit = self.current
   outfit = select(2, next(self.outfitOverride)) or outfit
   -- reset toggable models
   local toggableModelsPriority = {}
   for name, modelparts in pairs(self.toggableModels) do
      toggableModelsPriority[name] = -1
      for _, model in ipairs(modelparts) do
         model:visible(false)
      end
   end
   -- update layers
   for _, group in pairs(self.groups) do
      local current = outfit[group.title] or vec(0, 1, 1, 1)
      local id = current.x - 1
      local color = current.yzw
      local uv = matrices.mat3()
      uv:translate(
         id % group.clothesLimitX,
         math.floor(id / group.clothesLimitX)
      )
      uv:scale(group.uvScale)
      if id < 0 then
         for _, model in pairs(group.modelparts) do model:visible(false) end
      else
         for _, model in pairs(group.modelparts) do
            model:visible(true)
               :color(color)
               :uvMatrix(uv)
         end
      end
      local toggableModels = group.enableModels and group.enableModels[id + 1]
      if toggableModels then
         local name = toggableModels[1]
         if toggableModelsPriority[name] < group.distance then
            toggableModelsPriority[name] = group.distance
            local modelparts = self.toggableModels[name]
            local modelUv = toggableModels[2] * modelparts.uvSize
            for _, model in ipairs(modelparts) do
               model:visible(true)
                  :color(color)
                  :uvPixels(modelUv)
            end
         end
      end
   end
   -- update outfit data
   local newRenderedClothes = self:compressOutfit(outfit)
   if self.renderedClothes ~= newRenderedClothes then
      self.renderedClothes = newRenderedClothes
      if self.clothesChangeFunc and not ignoreChangeFunc then
         self.clothesChangeFunc()
      end
   end
end

---compresses provided or current outfit, can be used when sending pings to make pings smaller
---@param outfit? table
---@return string
function clothesHandler:compressOutfit(outfit)
   outfit = outfit or self.current
   local tbl = {}
   for _, group in pairs(self.groups) do
      local v = outfit[group.title] or vec(0, 1, 1, 1)
      table.insert(tbl, string.char(v.x))
      table.insert(tbl, string.char(v.y * 255))
      table.insert(tbl, string.char(v.z * 255))
      table.insert(tbl, string.char(v.w * 255))
   end
   return table.concat(tbl)
end

---decompresses outfit and returns it
---@param compressed string
---@return {[string]: Vector4}
function clothesHandler:decompressOutfit(compressed)
   local tbl = {}
   local groups = self.groups
   for i = 1, #compressed, 4 do
      local k = (i + 3) / 4
      local v = vec(string.byte(compressed:sub(i, i + 3), 1, -1))
      tbl[groups[k].title] = v.x___ + v._yzw / 255
   end
   return tbl
end

---sets outfit from compressed outfit
---@param received string
---@param ignoreChangeFunc? boolean -- if true clothes change function will be ignored
---@return self
function clothesHandler:setFromCompressedOutfit(received, ignoreChangeFunc)
   if self.currentCompressed ~= received then
      self.currentCompressed = received
      self.current = self:decompressOutfit(received)
      self:update(ignoreChangeFunc)
   end
   return self
end

---sends ping to sync clothes and optionally saves current clothes to config, returns self for chaining
---@param saveConfig? boolean
function clothesHandler:sync(saveConfig)
   if saveConfig and self.configName then
      config:save(self.configName, self.current)
   end
   self.ping(
      self:compressOutfit(self.current)
   )
end

---sets cloth, when cloth type is 0 it will turn off cloth group, will automatically sync, returns self for chaining
---@param self self
---@param clothGroup string
---@param clothType? number
---@param color? Vector3
---@return self
function clothesHandler:setCloth(clothGroup, clothType, color)
   local current = self.current[clothGroup]
   if clothType then
      current.x = clothType
   end
   if color then
      current.yzw = color:copy()
   end
   self:sync(true)
   return clothesHandler
end

---returns current cloth and its color
---@param clothGroup string
---@return number
---@return Vector3
function clothesHandler:getCloth(clothGroup)
   local current = self.current[clothGroup]
   return current.x, current.yzw --[[@as Vector3]]
end

---sets current outift (selected clothes), syncs clothes, returns self for chaining
---@param tbl {[string]: Vector4}
function clothesHandler:setOutfit(tbl)
   self.current = copyOutfit(tbl)
   self:sync(true)
   return clothesHandler
end

-- returns current outfit
---@return {[string]: Vector4}
function clothesHandler:getOutfit()
   return copyOutfit(self.current)
end

---sets function that will be called when clothes are changed, this might run even if player is not loaded, make sure to check if player exists first when needed, returns self for chaining
---@param func? function
---@return self
function clothesHandler:onClothesChange(func)
   self.clothesChangeFunc = func
   return self
end

return lib