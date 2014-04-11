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

PORT = process.env.PORT or 8080
KEY = process.env.KEY or config.password
METHOD = process.env.METHOD or config.method
timeout = config.timeout or 600
timeout = math.floor(timeout * 1000)

upgrade = (req, connection) ->
  p "server connected"

  connection\write table.concat {
      "HTTP/1.1 101 Web Socket Protocol Handshake\r\n",
      "Upgrade: WebSocket\r\n",
      "Connection: Upgrade\r\n",
      "\r\n"
    }, ""

  encryptor = Encryptor KEY, METHOD
  stage = 0
  headerLength = 0
  remote = nil
  cachedPieces = {}
  addrLen = 0
  remoteAddr = nil
  remotePort = nil
  req\on "data", (data) ->
    data = encryptor\decrypt data
    if stage == 5
      connection\pause! unless remote\write data
      return
    if stage == 0
      addrtype = string.byte data, 1
      if addrtype == 3
        addrLen = string.byte data, 2
      else unless addrtype == 1
        p "unsupported addrtype: #{addrtype}"
        connection\destroy!
        return
      -- read address and port
      if addrtype == 1
        remoteAddr = inetNtoa data\sub 2, 5
        remotePort = (Buffer\new data\sub 6, 7)\readUInt16BE 1
        headerLength = 7
      else
        remoteAddr = data\sub 3, 3 + addrLen - 1
        remotePort = (Buffer\new data\sub 3 + addrLen, 3 + addrLen + 1)\readUInt16BE 1
        headerLength = 2 + addrLen + 2
      -- connect remote server
      remote = net.create remotePort, remoteAddr, ->
        p "connecting #{remoteAddr}:#{remotePort}"

        for i = 1, #cachedPieces
          piece = cachedPieces[i]
          remote\write piece

        cachedPieces = nil -- save memory
        stage = 5

      remote\on "data", (data) ->
        data = encryptor\encrypt data
        remote\pause! unless connection\write data

      remote\on "end", ->
        p "remote disconnected"
        connection\done!

      remote\on "error", (e)->
        p "remote: #{e}"
        connection\done!

      remote\on "drain", ->
        connection\resume! if not connection.destroyed

      remote\setTimeout timeout, ->
        connection\destroy!
        remote\destroy!

      if (string.len data) > headerLength
        cachedPieces[#cachedPieces + 1] = data\sub headerLength + 1

      stage = 4
    else if stage == 4
      cachedPieces[#cachedPieces + 1] = data
      -- remote server not connected
      -- cache received buffers
      -- make sure no data is lost

  connection\on "end", ->
    p "server disconnected"
    remote\destroy! if remote

  connection\on "error", (e)->
    p "server: #{e}"
    remote\destroy! if remote

  connection\on "drain", ->
    remote\resume! if remote and not remote.destroyed

  connection\setTimeout timeout, ->
    remote\destroy! if remote
    connection\destroy!

server = http.createServer (req, res) ->
  if req.upgrade
    upgrade req, req.client
    return
  res\writeHead 200, { ["Content-Type"]: "text/plain" }
  res\finish 'Good Day!'

server\listen PORT, ->
  address = server\address!
  p "server listening at port #{address.address}:#{address.port}"
