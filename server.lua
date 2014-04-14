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
local PORT = process.env.PORT or 8080
local KEY = process.env.KEY or config.password
local METHOD = process.env.METHOD or config.method
local timeout = config.timeout or 600
timeout = math.floor(timeout * 1000)
local upgrade
upgrade = function(req, connection)
  p("server connected")
  connection:write(table.concat({
    "HTTP/1.1 101 Web Socket Protocol Handshake\r\n",
    "Upgrade: WebSocket\r\n",
    "Connection: Upgrade\r\n",
    "\r\n"
  }, ""))
  local encryptor = Encryptor(KEY, METHOD)
  local stage = 0
  local headerLength = 0
  local remote = nil
  local cachedPieces = { }
  local addrLen = 0
  local remoteAddr = nil
  local remotePort = nil
  req:on("data", function(data)
    data = encryptor:decrypt(data)
    if stage == 5 then
      if not (remote:write(data)) then
        connection:pause()
      end
      return 
    end
    if stage == 0 then
      return xpcall((function()
        local addrtype = string.byte(data, 1)
        if addrtype == 3 then
          addrLen = string.byte(data, 2)
        else
          if not (addrtype == 1) then
            p("unsupported addrtype: " .. tostring(addrtype))
            connection:destroy()
            return 
          end
        end
        if addrtype == 1 then
          remoteAddr = inetNtoa(data:sub(2, 5))
          remotePort = (Buffer:new(data:sub(6, 7))):readUInt16BE(1)
          headerLength = 7
        else
          remoteAddr = data:sub(3, 3 + addrLen - 1)
          remotePort = (Buffer:new(data:sub(3 + addrLen, 3 + addrLen + 1))):readUInt16BE(1)
          headerLength = 2 + addrLen + 2
        end
        remote = net.create(remotePort, remoteAddr, function()
          p("connecting " .. tostring(remoteAddr) .. ":" .. tostring(remotePort))
          for i = 1, #cachedPieces do
            local piece = cachedPieces[i]
            remote:write(piece)
          end
          cachedPieces = nil
          stage = 5
        end)
        remote:on("data", function(data)
          data = encryptor:encrypt(data)
          if not (connection:write(data)) then
            return remote:pause()
          end
        end)
        remote:on("end", function()
          p("remote disconnected")
          return connection:done()
        end)
        remote:on("error", function(e)
          p("remote: " .. tostring(e))
          remote:destroy()
          return connection:done()
        end)
        remote:on("drain", function()
          if not connection.destroyed then
            return connection:resume()
          end
        end)
        remote:setTimeout(timeout, function()
          connection:destroy()
          return remote:destroy()
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
    p("server disconnected")
    if remote then
      return remote:destroy()
    end
  end)
  connection:on("error", function(e)
    p("server: " .. tostring(e))
    connection:destroy()
    if remote then
      return remote:destroy()
    end
  end)
  connection:on("drain", function()
    if remote and not remote.destroyed then
      return remote:resume()
    end
  end)
  return connection:setTimeout(timeout, function()
    if remote then
      remote:destroy()
    end
    return connection:destroy()
  end)
end
local server = http.createServer(function(req, res)
  if req.upgrade then
    upgrade(req, req.client)
    return 
  end
  res:writeHead(200, {
    ["Content-Type"] = "text/plain"
  })
  return res:finish('Good Day!')
end)
return xpcall((function()
  server:listen(PORT, function() end)
  local address = server:address()
  return p("server listening at port " .. tostring(address.address) .. ":" .. tostring(address.port))
end), function(err)
  return p(err)
end)
