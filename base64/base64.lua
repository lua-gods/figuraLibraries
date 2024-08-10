local module = {}

---encode base64
---@param str string
---@return string
function module.encode(str)
   local buffer = data:createBuffer() 
   buffer:writeByteArray(str)
   buffer:setPosition(0)
   local output = buffer:readBase64()
   buffer:close()
   return output
end

---decode base64
---@param str string
---@return string
function module.decode(str)
   local buffer = data:createBuffer()
   buffer:writeBase64(str)
   buffer:setPosition(0)
   local output = buffer:readByteArray()
   buffer:close()
   return output
end

return module
