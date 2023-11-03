--[[ info
Simple figura script that tries to add traceback back to stack overflow
i suggest to only use it for debugging when your avatar have stack overflow and you cant find function that causes problem
how to use:
copy your autoScripts from avatar.json to config below or leave autoScripts empty if you dont use autoScripts
set autoScripts in avatar.json to: ["traceback"]
]]-- config
local autoScripts = {}
local tracebackLimit = 25

-- code
local myFileName = (...):gsub('.$', '%1.')..({...})[2]

-- patch
local function patch(text, codeToAdd)
   local code = {}

   local mode = 0
   local escapingString = false
   local bigStringlen = 0
   local i = 0
   for _ = 1, #text do
      i = i + 1
      if i > #text then break end
      local char = text:sub(i, i)
      if mode == 1 or mode == 2 then
         if escapingString then
            escapingString = false
         else
            if char == '\\' then
               escapingString = true
            elseif (mode == 1 and char == '"') or (mode == 2 and char == "'") then
               mode = 0
            end
         end
      elseif mode == 3 then
         local targetText = ']'..('='):rep(bigStringlen)..']'
         if text:sub(i, i + bigStringlen + 1) == targetText then
            mode = 0
            char = targetText
            i = i + bigStringlen + 1
         end
      else
         if char == '"' then
            mode = 1
         elseif char == "'" then
            mode = 2
         elseif char == '[' then
            local result = text:sub(i + 1, -1):match('^=*%[')
            if result then
               mode = 3
               bigStringlen = #result - 1
               i = i + bigStringlen + 1
               char = '['..result
            end
         elseif char == 'f' then
            local textToTest = text:sub(i + 1, -1)
            local result = textToTest:match('^unction%s+[a-zA-Z_][%w%s.:]*%([%w%s,.]*%)') or textToTest:match('^unction%s*%([%w%s,.]*%)')
            if result then
               i = i + #result
               char = 'f' .. result .. codeToAdd
            end
         end
      end
      table.insert(code, char)
   end

   return table.concat(code)
end

-- check traceback
local function errorFunc() error('') end

local function check()
   local _, err = pcall(errorFunc)
   local _, i = err:gsub('\n', '\n')
   if i > tracebackLimit then
      error('stack overflow', 2)
   end
end

-- load
local checkVarName = 'check'
for _ = 1, 8 do
   checkVarName = checkVarName..math.random(0, 9)
end

local envCache = {}
local envIds = {}
local luaLoad = load
function loadstring(code, name, env)
   local patchedCode = patch(code, checkVarName..'();')

   env = env or _ENV
   local envId
   if envIds[env] then
      envId = envIds[env]
   else
      table.insert(envCache, env)
      envIds[env] = #envCache
      envId = #envCache
   end

   local codeToAdd = 'local '..checkVarName..' = require("'..myFileName..'")(); _ENV = require("'..myFileName..'")('..envId..');'

   return luaLoad(
      codeToAdd .. patchedCode,
      name
   )
end
load = loadstring

local function getEnv(id)
   return envCache[id] or check
end

-- require
local scripts = avatar:getNBT().scripts

local scriptsOutput = {}
function require(file, fallbackFunction)
   if type(file) ~= "string" then error('bad argument: string expected, got nil', 2) end

   file = file:gsub("/", ".")
   if file == myFileName then
      return getEnv
   end

   if not scriptsOutput[file] then
      if not scripts[file] then error('Tried to require nonexistent script "'..file..'"!', 2) end

      local code = {}
      for _, byte in pairs(scripts[file]) do
         table.insert(code, string.char(byte % 256))
      end

      local func, err = load(table.concat(code), file)
      if func then
         local folderPath, fileName = file:match('^(.*)%.(.-)$')
         if not folderPath then
            folderPath, fileName = '', file
         end
         scriptsOutput[file] = {func(folderPath, fileName)}
      elseif fallbackFunction then
         fallbackFunction(file)
      else
         error(err, 2)
      end
   end

   return table.unpack(scriptsOutput[file])
end

-- load scripts
for _, v in pairs(#autoScripts >= 1 and autoScripts or listFiles('', true)) do
   require(v)
end
