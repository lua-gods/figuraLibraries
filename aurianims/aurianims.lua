---@class aurianims
local lib = {}
---@class aurianims.controller
local animController = {}
animController.__index = animController
---@class aurianims.node
local nodeClass = {type = nil}

local controllers = {}

---creates new animation controller
---@return aurianims.controller
function lib.new()
   local obj = {
      data = {},
      tree = {}
   }
   setmetatable(obj, animController)
   table.insert(controllers, obj)
   return obj
end

---sets function that can add data that can be later used in nodes, returns self for selfchaining
---@param func fun(new: table, old: table)
---@param startData table?
---@return aurianims.controller
function animController:setDriver(func, startData)
   self.dataFunc = func
   if startData then
      self.data = startData
   end
   return self
end

---sets tree of nodes with animations, returns self for selfchaining
---@param tree aurianims.node
---@return aurianims.controller
function animController:setTree(tree)
   self.tree = tree
   return self
end

---creates mix node, mix function return value controls what animation should be used 0 is 100% of anim1 and 0% of anim2, 1 is 0% of anim1 and 100% of anim2, values below 0 or above 1 will be clamped 
---@param func fun(data: table, old: number, anim1: aurianims.node|Animation, anim2: aurianims.node|Animation): blend: number, instant: boolean?
---@param anim1 aurianims.node|Animation
---@param anim2 aurianims.node|Animation
---@return aurianims.node
function lib.mix(func, anim1, anim2)
   return {
      type = 'mix',
      func = func,
      anim1 = anim1,
      anim2 = anim2,
      blend = 0,
      oldBlend = 0
   }
end

---creates stack node, allows to use multiple animations or nodes at once
---@param anims aurianims.node[]|Animation[]
---@return aurianims.node
function lib.stack(anims)
   return {
      type = 'stack',
      anims = anims
   }
end

---creates blend mode allows to control how much animation will be used depending on return value from function 
---@param func fun(data: table, old: number, anim: aurianims.node|Animation): blend: number, instant: boolean?
---@param anim any
---@return table
function lib.blend(func, anim)
   return {
      type = 'blend',
      func = func,
      anim = anim,
      blend = 0,
      oldBlend = 0
   }
end

local nodesUpdate
local function update(controller, node, blend)
   if type(node) == 'Animation' then
      node:setPlaying(blend > 0.001)
      return
   end
   nodesUpdate[node.type](controller, node, blend)
end

nodesUpdate = {
   mix = function(controller, node, blendMul)
      node.oldBLend = node.blend
      local blend, instant = node.func(controller.data, node.blend, node.anim1, node.anim2)
      blend = math.clamp(blend, 0, 1)
      node.blend = blend
      if instant then node.oldBLend = blend end
      update(controller, node.anim1, blendMul * (1 - blend))
      update(controller, node.anim2, blendMul * blend)
   end,
   stack = function(controller, node, blendMul)
      for _, v in pairs(node.anims) do
         update(controller, v, blendMul)
      end
   end,
   blend = function(controller, node, blendMul)
      node.oldBLend = node.blend
      local blend, instant = node.func(controller.data, node.blend, node.anim1, node.anim2)
      blend = math.clamp(blend, 0, 1)
      node.blend = blend
      if instant then node.oldBLend = blend end
      update(controller, node.anim, blendMul * blend)
   end,
}


local nodesUpdateRender
local function updateRender(delta, controller, node, blend)
   if type(node) == 'Animation' then
      node:blend(blend)
      return
   end
   nodesUpdateRender[node.type](delta, controller, node, blend)
end

nodesUpdateRender = {
   mix = function(delta, controller, node, blendMul)
      local blend = math.lerp(node.oldBLend, node.blend, delta)
      updateRender(delta, controller, node.anim1, blendMul * (1 - blend))
      updateRender(delta, controller, node.anim2, blendMul * blend)
   end,
   stack = function(delta, controller, node, blendMul)
      for _, v in pairs(node.anims) do
         updateRender(delta, controller, v, blendMul)
      end
   end,
   blend = function(delta, controller, node, blendMul)
      local blend = math.lerp(node.oldBLend, node.blend, delta)
      updateRender(delta, controller, node.anim, blendMul * blend)
   end
}

function events.tick()
   for _, v in pairs(controllers) do
      if v.dataFunc then
         v.dataFunc(v.data)
      end
      update(v, v.tree, 1)
   end
end

function events.render(delta)
   for _, v in pairs(controllers) do
      updateRender(delta, v, v.tree, 1)
   end
end

return lib