local parseArgs
parseArgs = function()
  local args = {
    ['-l'] = 'local_port',
    ['-r'] = 'remote_port',
    ['-s'] = 'server',
    ['-k'] = 'password',
    ['-c'] = 'config_file',
    ['-m'] = 'method'
  }
  local result = { }
  local nextIsValue = false
  local lastKey = null
  for _, arg in pairs(process.argv) do
    if nextIsValue then
      result[lastKey] = arg
      nextIsValue = false
    else
      if args[arg] then
        lastKey = args[arg]
        nextIsValue = true
      end
    end
  end
  return result
end
local version = "shadowsocks-websocket-luvit 0.0.1"
return {
  version = version,
  parseArgs = parseArgs
}
