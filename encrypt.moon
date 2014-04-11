math = require "math"
table = require "table"
string = require "string"
crypto = require "_crypto"
import Buffer from require "buffer"
import merge_sort from require "./merge_sort"

int32Max = math.pow 2, 32
cachedTables = {} -- password: [encryptTable, decryptTable]

getTable = (key) ->
  if cachedTables[key]
    return cachedTables[key]
  p "calculating ciphers"
  encryptTable = [i - 1 for i=1,256]
  decryptTable = [0 for i=1,256]
  md5sum = crypto.digest.new "md5"
  md5sum\update key
  hash = Buffer\new md5sum\final "", true
  al = hash\readUInt32LE 1
  ah = hash\readUInt32LE 5

  for i = 2, 1024 - 1
    encryptTable = merge_sort encryptTable, (x, y) ->
      ((ah % (x + i)) * int32Max + al) % (x + i) <= ((ah % (y + i)) * int32Max + al) % (y + i)

  for i = 1, 256
    decryptTable[encryptTable[i] + 1] = i - 1

  result = {encryptTable, decryptTable}
  cachedTables[key] = result
  result

encrypt = (tbl, buf) ->
  result = {}
  for i = 1, buf\len!
    table.insert result, string.char tbl[(buf\byte i) + 1]
  table.concat result, ""

EVP_BytesToKey = (password, key_len, iv_len) ->
  -- equivalent to OpenSSL's EVP_BytesToKey() with count 1
  -- so that we make the same key and iv as Node version
  m = {}
  i = 1
  while #(table.concat m, "") < (key_len + iv_len)
    md5 = crypto.digest.new "md5"
    data = password
    if i > 1
      data = m[i - 1] + password
    md5\update data
    table.insert m, md5\final "", true
    i += 1
  ms = table.concat m, ""
  key = ms\sub 1, key_len
  iv = ms\sub key_len + 1, key_len + iv_len
  key, iv

class Encryptor
  new: (key, @method) =>
    if @method == "" or @method == "table"
      @method = nil
    if @method
      key, iv = EVP_BytesToKey key, 16, 0
      @cipher = crypto.encrypt.new @method, key
      @decipher = crypto.decrypt.new @method, key
    else
      {@encryptTable, @decryptTable} = getTable key

  encrypt: (buf) =>
    if @method
      @cipher\update buf
    else
      encrypt @encryptTable, buf

  decrypt: (buf) =>
    if @method
      @decipher\update buf
    else
      encrypt @decryptTable, buf

{:Encryptor, :getTable, :EVP_BytesToKey}
