os = require "os"
net = require "net"
http = require "http"
math = require "math"
table = require "table"
string = require "string"
fs = require "fs"
path = require "path"
JSON = require "json"
import Buffer from require "buffer"
args = require "./args"
import Encryptor from require "./encrypt"

p args.version

math.randomseed os.time!
math.random!
math.random!
math.random!

inetNtoa = (buf) ->
  (buf\byte 1) .. "." .. (buf\byte 2) .. "." .. (buf\byte 3) .. "." .. (buf\byte 4)

inetAton = (ipStr) ->
  parts = [x for x in string.gmatch ipStr .. ".", "(%d+)%."]
  unless #parts == 4
    nil
  else
    table.concat [string.char c for c in *parts], ""

configFromArgs = args.parseArgs!
configFile = configFromArgs.config_file
configContent = "{}"
if configFile
  configContent = fs.readFileSync path.resolve __dirname, configFile
config = JSON.parse configContent
for k, v in pairs configFromArgs
  config[k] = v

p config

SERVER = config.server
REMOTE_PORT = config.remote_port or 80
PORT = tonumber config.local_port
KEY = config.password
METHOD = config.method
timeout = config.timeout or 600
timeout = math.floor(timeout * 1000)

getServer = ->
  if (type SERVER) == "table"
    SERVER[math.random #SERVER]
  else
    SERVER

server = net.createServer (connection) ->
  p "local connected"
  encryptor = Encryptor KEY, METHOD
  stage = 0
  headerLength = 0
  remote = nil
  req = nil
  cachedPieces = {}
  addrLen = 0
  remoteAddr = nil
  remotePort = nil
  addrToSend = ""
  aServer = getServer!
  connection\on "data", (data) ->
    if stage == 5
      -- pipe sockets
      data = encryptor\encrypt data
      connection\pause! unless remote\write data
      return
    if stage == 0
      connection\write "\x05\x00"
      stage = 1
      return
    if stage == 1
      xpcall (->
          -- +----+-----+-------+------+----------+----------+
          -- |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
          -- +----+-----+-------+------+----------+----------+
          -- | 1  |  1  | X'00' |  1   | Variable |    2     |
          -- +----+-----+-------+------+----------+----------+

          -- cmd and addrtype
          cmd = string.byte data, 2
          addrtype = string.byte data, 4
          unless cmd == 1
            p "unsupported cmd: #{cmd}"
            connection\write "\x05\x07\x00\x01"
            connection\done!
            return
          if addrtype == 3
            addrLen = string.byte data, 5
          else unless addrtype == 1
            p "unsupported addrtype: #{addrtype}"
            connection\done!
            return
          addrToSend = string.char data\byte 4
          -- read address and port
          if addrtype == 1
            remoteAddr = inetNtoa data\sub 5, 8
            addrToSend ..= data\sub 5, 10
            remotePort = data\sub 9, 10
            headerLength = 10
          else
            remoteAddr = data\sub 6, 6 + addrLen - 1
            addrToSend ..= data\sub 5, 6 + addrLen + 2 - 1
            remotePort = data\sub 6 + addrLen, 6 + addrLen + 2 - 1
            headerLength = 5 + addrLen + 2
          connection\write "\x05\x00\x00\x01\x00\x00\x00\x00" .. remotePort
          -- connect remote server
          req = http.request {
            host: aServer,
            port: REMOTE_PORT,
            headers:
              'Connection': 'Upgrade',
              'Upgrade': 'websocket'
            }, (response) ->
              response\on "end", ->
                if response.status_code == 101 -- Switching Protocols
                  response.upgrade = true
                  req\emit 'upgrade', response
          req\done!
          req\setTimeout timeout, ->
            p "req timeout"
            req\destroy! if req
            remote\destroy! if remote
            connection\done!

          req\on 'error', (e)->
            p "req #{e}"
            req\destroy! if req
            remote\destroy! if remote
            connection\done!

          req\on 'upgrade', (res) ->
            remote = res.socket
            p "remote got upgrade"
            p "connecting #{remoteAddr}:#{(Buffer\new remotePort)\readUInt16BE 1} via #{aServer}"
            addrToSendBuf = encryptor\encrypt addrToSend
            remote\write addrToSendBuf

            for i = 1, #cachedPieces
              piece = cachedPieces[i]
              piece = encryptor\encrypt piece
              remote\write piece

            cachedPieces = nil -- save memory
            stage = 5

            res\on "data", (data) ->
              data = encryptor\decrypt data
              remote\pause! unless connection\write data

            remote\on "end", ->
              p "remote disconnected"
              connection\done!

            remote\on "error", (e) ->
              p "remote #{remoteAddr}:#{(Buffer\new remotePort)\readUInt16BE 1} error: #{e}"
              remote\destroy!
              connection\destroy!

            remote\on "drain", ->
              connection\resume! if not connection.destroyed

            remote\setTimeout timeout, ->
              remote\destroy!
              connection\destroy!

          if (string.len data) > headerLength
            cachedPieces[#cachedPieces + 1] = data\sub headerLength + 1

          stage = 4),
        (err) ->
          p err

    else if stage == 4
      cachedPieces[#cachedPieces + 1] = data
      -- remote server not connected
      -- cache received buffers
      -- make sure no data lost

  connection\on "end", ->
    p "local disconnected"
    req\destroy! if req
    remote\destroy! if remote

  connection\on "error", (e)->
    p "local error: #{e}"
    connection\destroy!
    req\destroy! if req
    remote\destroy! if remote

  connection\on "drain", ->
    remote\resume! if remote and not remote.destroyed and stage == 5

  connection\setTimeout timeout, ->
    p "local timedout"
    connection\destroy!
    req\destroy! if req
    remote\destroy! if remote

xpcall (->
    server\listen PORT, ->
    address = server\address!
    p "server listening at port #{address.address}:#{address.port}"),
  (err) ->
    p err
