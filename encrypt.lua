local math = require("math")
local table = require("table")
local string = require("string")
local crypto = require("_crypto")
local Buffer
do
  local _obj_0 = require("buffer")
  Buffer = _obj_0.Buffer
end
local merge_sort
do
  local _obj_0 = require("./merge_sort")
  merge_sort = _obj_0.merge_sort
end
local int32Max = math.pow(2, 32)
local cachedTables = { }
local getTable
getTable = function(key)
  if cachedTables[key] then
    return cachedTables[key]
  end
  p("calculating ciphers")
  local encryptTable
  do
    local _accum_0 = { }
    local _len_0 = 1
    for i = 1, 256 do
      _accum_0[_len_0] = i - 1
      _len_0 = _len_0 + 1
    end
    encryptTable = _accum_0
  end
  local decryptTable
  do
    local _accum_0 = { }
    local _len_0 = 1
    for i = 1, 256 do
      _accum_0[_len_0] = 0
      _len_0 = _len_0 + 1
    end
    decryptTable = _accum_0
  end
  local md5sum = crypto.digest.new("md5")
  md5sum:update(key)
  local hash = Buffer:new(md5sum:final("", true))
  local al = hash:readUInt32LE(1)
  local ah = hash:readUInt32LE(5)
  for i = 2, 1024 - 1 do
    encryptTable = merge_sort(encryptTable, function(x, y)
      return ((ah % (x + i)) * int32Max + al) % (x + i) <= ((ah % (y + i)) * int32Max + al) % (y + i)
    end)
  end
  for i = 1, 256 do
    decryptTable[encryptTable[i] + 1] = i - 1
  end
  local result = {
    encryptTable,
    decryptTable
  }
  cachedTables[key] = result
  return result
end
local encrypt
encrypt = function(tbl, buf)
  local result = { }
  for i = 1, buf:len() do
    table.insert(result, string.char(tbl[(buf:byte(i)) + 1]))
  end
  return table.concat(result, "")
end
local EVP_BytesToKey
EVP_BytesToKey = function(password, key_len, iv_len)
  local m = { }
  local i = 1
  while #(table.concat(m, "")) < (key_len + iv_len) do
    local md5 = crypto.digest.new("md5")
    local data = password
    if i > 1 then
      data = m[i - 1] + password
    end
    md5:update(data)
    table.insert(m, md5:final("", true))
    i = i + 1
  end
  local ms = table.concat(m, "")
  local key = ms:sub(1, key_len)
  local iv = ms:sub(key_len + 1, key_len + iv_len)
  return key, iv
end
local Encryptor
do
  local _base_0 = {
    encrypt = function(self, buf)
      if self.method then
        return self.cipher:update(buf)
      else
        return encrypt(self.encryptTable, buf)
      end
    end,
    decrypt = function(self, buf)
      if self.method then
        return self.decipher:update(buf)
      else
        return encrypt(self.decryptTable, buf)
      end
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self, key, method)
      self.method = method
      if self.method == "" or self.method == "table" then
        self.method = nil
      end
      if self.method then
        local iv
        key, iv = EVP_BytesToKey(key, 16, 0)
        self.cipher = crypto.encrypt.new(self.method, key)
        self.decipher = crypto.decrypt.new(self.method, key)
      else
        do
          local _obj_0 = getTable(key)
          self.encryptTable, self.decryptTable = _obj_0[1], _obj_0[2]
        end
      end
    end,
    __base = _base_0,
    __name = "Encryptor"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Encryptor = _class_0
end
return {
  Encryptor = Encryptor,
  getTable = getTable,
  EVP_BytesToKey = EVP_BytesToKey
}
