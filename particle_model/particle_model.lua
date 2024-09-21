local lib = {}

local avatarNbt = avatar:getNBT()
local modelsNbt, texturesNbt = avatarNbt.models, avatarNbt.textures.data
avatarNbt = nil

local renderSteps = 16
local maxRenderSteps = 48
local particleSize = 1

local function defaultSpawnParticle(pos, color)
   if color.a < 0.1 then return end
   particles['end_rod']
      :pos(pos)
      :lifetime(10000)
      :gravity(0)
      :size(particleSize)
      :color(color)
      :spawn()
end
local spawnParticle = defaultSpawnParticle

local function getModelNbt(model)
   -- find path in nbt
   local nbtPath = {}
   local part = model
   for _ = 1, 50 do
      table.insert(nbtPath, part:getName())
      part = part:getParent()
      if not part then break end
   end
   -- go to path in avatar nbt
   local modelNbt = modelsNbt
   for i = #nbtPath - 1, 1, -1 do
      for k, v in pairs(modelNbt.chld) do
         if v.name == nbtPath[i] then
            modelNbt = modelNbt.chld[k]
         end
      end
   end
   return modelNbt
end

-- 3 4
-- 1 2 
-- lerp: (b - a) * t + a
local function renderQuad(p1, p2, p3, p4, uv1, uv2, uv3, uv4, texture)
   -- calculate best quality
   local qualityX = 1 / math.clamp(math.ceil((p1 - p2):length() * renderSteps), 1, maxRenderSteps)
   local qualityY = 1 / math.clamp(math.ceil((p1 - p3):length() * renderSteps), 1, maxRenderSteps)
   -- adjust uv
   local uvCenter = (uv1 + uv2 + uv3 + uv4) * 0.0025 -- 0.25 * 0.01
   uv1 = uv1 * 0.99 + uvCenter
   uv2 = uv2 * 0.99 + uvCenter
   uv3 = uv3 * 0.99 + uvCenter
   uv4 = uv4 * 0.99 + uvCenter
   -- loop thourgh pixels
   local textureSize = texture:getDimensions()
   for x = 0, 1, qualityX do
      local p12 = (p2 - p1) * x + p1
      local p34 = (p4 - p3) * x + p3
      local uv12 = (uv2 - uv1) * x + uv1
      local uv34 = (uv4 - uv3) * x + uv3
      for y = 0, 1, qualityY do
         local p = (p34 - p12) * y + p12
         local uv = (uv34 - uv12) * y + uv12
         spawnParticle(
            p,
            texture:getPixel(
               uv.x % textureSize.x,
               uv.y % textureSize.y
            )
         )
      end
   end
end

local function renderTriangle(p1, p2, p3, uv1, uv2, uv3, texture)
   local qualityX = 1 / math.clamp(math.ceil((p1 - p3):length() * renderSteps), 1, maxRenderSteps)
   local qualityY = math.clamp((p1 - p2):length() * renderSteps, 1, maxRenderSteps)
   -- adjust uv
   local uvCenter = (uv1 + uv2 + uv3) * 0.333 * 0.01 -- 0.333 * 0.01
   uv1 = uv1 * 0.99 + uvCenter
   uv2 = uv2 * 0.99 + uvCenter
   uv3 = uv3 * 0.99 + uvCenter
   -- loop
   local textureSize = texture:getDimensions()
   for x = 0, 1, qualityX do
      local p13 = (p1 - p3) * x + p3
      local p23 = (p2 - p3) * x + p3
      local uv13 = (uv1 - uv3) * x + uv3
      local uv23 = (uv2 - uv3) * x + uv3
      local steps = math.ceil(qualityY * x)
      for y = 0, 1, 1 / steps do
         local p = math.lerp(p13, p23, y)
         local uv = math.lerp(uv13, uv23, y)
         spawnParticle(
            p,
            texture:getPixel(
               uv.x % textureSize.x,
               uv.y % textureSize.y
            )
         )
      end
   end
end

local function renderCubeFace(p1, p2, p3, p4, faceData)
   if not faceData then return end
   local texture = textures[texturesNbt[faceData.tex + 1].d]
   local uv = vec(table.unpack(faceData.uv))
   if faceData.rot then
      p3, p4 = p4, p3
      for _ = 1, 1 do
         p1, p2, p3, p4 = p4, p1, p2, p3 
      end
      p3, p4 = p4, p3
   end
   renderQuad(p1, p2, p3, p4, uv.xy, uv.zy, uv.xw, uv.zw, texture)
end

local function renderMesh(nbt, model)
   local partToWorldMat = model:partToWorldMatrix()
   local modelPivot = model:getPivot()
   local meshData = nbt.mesh_data

   local vertexIdType = #meshData.vtx > 32767 * 3 and 2 or #meshData.vtx > 255 * 3 and 1 or 0;
   local i = 1
   for _, tex in pairs(meshData.tex) do -- loop through textures first because it contains the amount of vertices used in face
      local textureId = bit32.rshift(tex, 4)
      local texture = textures[texturesNbt[textureId + 1].d]
      local vertexCount = bit32.band(tex, 15)
      local vertices = {}
      local uvs = {}
      for k = 0, vertexCount - 1 do
         local faceId = i + k
         local vertexId = meshData.fac[faceId]
         if vertexIdType == 0 then
            vertexId = vertexId % 256
         elseif vertexIdType == 1 then
            vertexId = vertexId % 65536
         end
         vertexId = vertexId * 3 + 1 -- lua starts from 1 remember
         local pos = vec(meshData.vtx[vertexId], meshData.vtx[vertexId + 1], meshData.vtx[vertexId + 2])
         local uv = vec(meshData.uvs[faceId * 2 - 1], meshData.uvs[faceId * 2])
         table.insert(vertices, partToWorldMat:apply(pos - modelPivot))
         table.insert(uvs, uv)
      end
      if vertexCount == 4 then
         renderQuad(
            vertices[1], vertices[2], vertices[4], vertices[3],
            uvs[1], uvs[2], uvs[4], uvs[3],
            texture
         )
      elseif vertexCount == 3 then
         renderTriangle(
            vertices[1], vertices[2], vertices[3],
            uvs[1], uvs[2], uvs[3],
            texture
         )
      end
      i = i + vertexCount
   end
end

local function renderCube(nbt, model)
   local partToWorldMat = model:partToWorldMatrix()
   local modelPivot = model:getPivot()

   local cubeStart = vec(table.unpack(nbt.f)) -- from
   local cubeEnd   = vec(table.unpack(nbt.t)) -- to

   local xyz = partToWorldMat:apply(cubeStart                   - modelPivot)
   local Xyz = partToWorldMat:apply(cubeStart._yz + cubeEnd.x__ - modelPivot)
   local xYz = partToWorldMat:apply(cubeStart.x_z + cubeEnd._y_ - modelPivot)
   local XYz = partToWorldMat:apply(cubeStart.__z + cubeEnd.xy_ - modelPivot)
   local xyZ = partToWorldMat:apply(cubeStart.xy_ + cubeEnd.__z - modelPivot)
   local XyZ = partToWorldMat:apply(cubeStart._y_ + cubeEnd.x_z - modelPivot)
   local xYZ = partToWorldMat:apply(cubeStart.x__ + cubeEnd._yz - modelPivot)
   local XYZ = partToWorldMat:apply(cubeStart.___ + cubeEnd.xyz - modelPivot)

   local cubeData = nbt.cube_data

   renderCubeFace(XYz, xYz, Xyz, xyz, cubeData.n)
   renderCubeFace(xYZ, XYZ, xyZ, XyZ, cubeData.s)
   renderCubeFace(XYZ, XYz, XyZ, Xyz, cubeData.e)
   renderCubeFace(xYz, xYZ, xyz, xyZ, cubeData.w)
   renderCubeFace(xYz, XYz, xYZ, XYZ, cubeData.u)
   renderCubeFace(xyZ, XyZ, xyz, Xyz, cubeData.d)
end

local function loopThroughAllParts(nbt, model, limit)
   limit = limit - 1
   if limit < 0 then return end
   if not model then return end
   if not nbt then return end
   if model:getVisible() == false then return end
   if nbt.cube_data then
      renderCube(nbt, model)
      return
   elseif nbt.mesh_data then
      renderMesh(nbt, model)
      return
   end
   if not nbt.chld then return end
   for i, childModel in pairs(model:getChildren()) do
      local childNbt = nbt.chld[i]
      loopThroughAllParts(childNbt, childModel, limit)
   end
end

---generates model out of particles
---@param model ModelPart -- model that will be turned into particles
---@param steps number? -- amount of steps per block, higher will give better quality but will be slower and might hit particle limit
---@param maxSteps number? -- max amount of steps per tri, quad
---@param particleFunc fun(pos: Vector3, color: Vector4)? -- function that will be used for spawning particles
function lib.render(model, steps, maxSteps, particleFunc)
   renderSteps = steps or 16
   particleSize = 6 / renderSteps
   maxRenderSteps = maxSteps or 48
   spawnParticle = particleFunc or defaultSpawnParticle
   loopThroughAllParts(
      getModelNbt(model),
      model,
      50
   )
end


return lib
