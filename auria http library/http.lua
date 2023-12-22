local lib = {}
local requests = {}

--- sends http request and calls finish function when done
--- @param uri string
--- @param finish fun(result: string, err: number | string)
--- @param outputType allowedOutputTypes?
--- @param headers table?
function lib.get(uri, finish, outputType, headers)
   if not net:isNetworkingAllowed(uri) then finish(nil, 'networkingNotAllowed') return end
   if not net:isLinkAllowed(uri) then finish(nil, 'linkNotAllowed') return end
   local request = net.http:request(uri)
   for i, v in pairs(headers or {}) do
      request:setHeader(i, v)
   end
   table.insert(requests, {
      future = request:send(),
      finish = finish,
      output = {},
      outputType = outputType or 'string'
   })
end

local readers
--- @enum (key) allowedOutputTypes
readers = {
   string = function(responseData, output)
      for _ = 1, 8 do
         if responseData:available() < 1 then return end
         local byte = responseData:read()
         if byte < 0 then
            return table.concat(output)
         end
         table.insert(output, string.char(byte))
         local buffer = data:createBuffer()
         buffer:readFromStream(responseData, responseData:available())
         buffer:setPosition(0)
         table.insert(output, buffer:readByteArray())
         buffer:close()
      end
   end,
   base64 = function(responseData, outputTbl)
      local output = readers.string(responseData, outputTbl)
      if output then
         local buffer = data:createBuffer()
         buffer:writeByteArray(output)
         buffer:setPosition(0)
         local base64 = buffer:readBase64()
         buffer:close()
         return base64
      end
   end,
   byteArray = function(responseData, output)
      for _ = 1, 8 do
         local available = responseData:available()
         for _ = 1, available - 1 do
            table.insert(output, responseData:read())
         end
         if available > 0 then
            local byte = responseData:read()
            if byte < 0 then return output end
            table.insert(output, byte)
         end
      end
   end,
}

function events.world_tick()
   for i, v in pairs(requests) do
      if v.future then
         if v.future:isDone() then
            local response = v.future:getValue()
            local code = response:getResponseCode()
            if code == 200 then
               v.responseData = response:getData()
               v.future = nil
            else
               v.finish(nil, code)
               requests[i] = nil
            end
         end
      else
         local output = readers[v.outputType](v.responseData, v.output)
         if output then
            v.finish(output)
            requests[i] = nil
            return
         end
      end
   end
end

return lib
