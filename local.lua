local os = require("os")
local net = require("net")
local http = require("http")
local math = require("math")
local table = require("table")
local string = require("string")
local fs = require("fs")
local path = require("path")
local JSON = require("json")
local Buffer
do
  local _obj_0 = require("buffer")
  Buffer = _obj_0.Buffer
end
local args = require("./args")
local Encryptor
do
  local _obj_0 = require("./encrypt")
  Encryptor = _obj_0.Encryptor
end
p(args.version)
math.randomseed(os.time())
math.random()
math.random()
math.random()
local inetNtoa
inetNtoa = function(buf)
  return (buf:byte(1)) .. "." .. (buf:byte(2)) .. "." .. (buf:byte(3)) .. "." .. (buf:byte(4))
end
local inetAton
inetAton = function(ipStr)
  local parts
  do
    local _accum_0 = { }
    local _len_0 = 1
    for x in string.gmatch(ipStr .. ".", "(%d+)%.") do
      _accum_0[_len_0] = x
      _len_0 = _len_0 + 1
    end
    parts = _accum_0
  end
  if not (#parts == 4) then
    return nil
  else
    return table.concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #parts do
        local c = parts[_index_0]
        _accum_0[_len_0] = string.char(c)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), "")
  end
end
local configFromArgs = args.parseArgs()
local configFile = configFromArgs.config_file
local configContent = "{}"
if configFile then
  configContent = fs.readFileSync(path.resolve(__dirname, configFile))
end
local config = JSON.parse(configContent)
for k, v in pairs(configFromArgs) do
  config[k] = v
end
p(config)
local SERVER = config.server
local REMOTE_PORT = config.remote_port or 80
local PORT = tonumber(config.local_port)
local KEY = config.password
local METHOD = config.method
local timeout = config.timeout or 600
timeout = math.floor(timeout * 1000)
local getServer
getServer = function()
  if (type(SERVER)) == "table" then
    return SERVER[math.random(#SERVER)]
  else
    return SERVER
  end
end
local server = net.createServer(function(connection)
  p("local connected")
  local encryptor = Encryptor(KEY, METHOD)
  local stage = 0
  local headerLength = 0
  local remote = nil
  local req = nil
  local cachedPieces = { }
  local addrLen = 0
  local remoteAddr = nil
  local remotePort = nil
  local addrToSend = ""
  local aServer = getServer()
  connection:on("data", function(data)
    if stage == 5 then
      data = encryptor:encrypt(data)
      if not (remote:write(data)) then
        connection:pause()
      end
      return 
    end
    if stage == 0 then
      connection:write("\x05\x00")
      stage = 1
      return 
    end
    if stage == 1 then
      return xpcall((function()
        local cmd = string.byte(data, 2)
        local addrtype = string.byte(data, 4)
        if not (cmd == 1) then
          p("unsupported cmd: " .. tostring(cmd))
          connection:write("\x05\x07\x00\x01")
          connection:done()
          return 
        end
        if addrtype == 3 then
          addrLen = string.byte(data, 5)
        else
          if not (addrtype == 1) then
            p("unsupported addrtype: " .. tostring(addrtype))
            connection:done()
            return 
          end
        end
        addrToSend = string.char(data:byte(4))
        if addrtype == 1 then
          remoteAddr = inetNtoa(data:sub(5, 8))
          addrToSend = addrToSend .. data:sub(5, 10)
          remotePort = data:sub(9, 10)
          headerLength = 10
        else
          remoteAddr = data:sub(6, 6 + addrLen - 1)
          addrToSend = addrToSend .. data:sub(5, 6 + addrLen + 2 - 1)
          remotePort = data:sub(6 + addrLen, 6 + addrLen + 2 - 1)
          headerLength = 5 + addrLen + 2
        end
        connection:write("\x05\x00\x00\x01\x00\x00\x00\x00" .. remotePort)
        req = http.request({
          host = aServer,
          port = REMOTE_PORT,
          headers = {
            ['Connection'] = 'Upgrade',
            ['Upgrade'] = 'websocket'
          }
        }, function(response)
          return response:on("end", function()
            if response.status_code == 101 then
              response.upgrade = true
              return req:emit('upgrade', response)
            end
          end)
        end)
        req:done()
        req:setTimeout(timeout, function()
          p("req timeout")
          if req then
            req:destroy()
          end
          if remote then
            remote:destroy()
          end
          return connection:done()
        end)
        req:on('error', function(e)
          p("req " .. tostring(e))
          if req then
            req:destroy()
          end
          if remote then
            remote:destroy()
          end
          return connection:done()
        end)
        req:on('upgrade', function(res)
          remote = res.socket
          p("remote got upgrade")
          p("connecting " .. tostring(remoteAddr) .. ":" .. tostring((Buffer:new(remotePort)):readUInt16BE(1)) .. " via " .. tostring(aServer))
          local addrToSendBuf = encryptor:encrypt(addrToSend)
          remote:write(addrToSendBuf)
          for i = 1, #cachedPieces do
            local piece = cachedPieces[i]
            piece = encryptor:encrypt(piece)
            remote:write(piece)
          end
          cachedPieces = nil
          stage = 5
          res:on("data", function(data)
            data = encryptor:decrypt(data)
            if not (connection:write(data)) then
              return remote:pause()
            end
          end)
          remote:on("end", function()
            p("remote disconnected")
            return connection:done()
          end)
          remote:on("error", function(e)
            p("remote " .. tostring(remoteAddr) .. ":" .. tostring((Buffer:new(remotePort)):readUInt16BE(1)) .. " error: " .. tostring(e))
            remote:destroy()
            return connection:destroy()
          end)
          remote:on("drain", function()
            if not connection.destroyed then
              return connection:resume()
            end
          end)
          return remote:setTimeout(timeout, function()
            remote:destroy()
            return connection:destroy()
          end)
        end)
        if (string.len(data)) > headerLength then
          cachedPieces[#cachedPieces + 1] = data:sub(headerLength + 1)
        end
        stage = 4
      end), function(err)
        return p(err)
      end)
    else
      if stage == 4 then
        cachedPieces[#cachedPieces + 1] = data
      end
    end
  end)
  connection:on("end", function()
    p("local disconnected")
    if req then
      req:destroy()
    end
    if remote then
      return remote:destroy()
    end
  end)
  connection:on("error", function(e)
    p("local error: " .. tostring(e))
    connection:destroy()
    if req then
      req:destroy()
    end
    if remote then
      return remote:destroy()
    end
  end)
  connection:on("drain", function()
    if remote and not remote.destroyed and stage == 5 then
      return remote:resume()
    end
  end)
  return connection:setTimeout(timeout, function()
    p("local timedout")
    connection:destroy()
    if req then
      req:destroy()
    end
    if remote then
      return remote:destroy()
    end
  end)
end)
return xpcall((function()
  server:listen(PORT, function() end)
  local address = server:address()
  return p("server listening at port " .. tostring(address.address) .. ":" .. tostring(address.port))
end), function(err)
  return p(err)
end)
