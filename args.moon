parseArgs = ->
  args =
    '-l': 'local_port'
    '-r': 'remote_port'
    '-s': 'server'
    '-k': 'password',
    '-c': 'config_file',
    '-m': 'method'

  result = {}
  nextIsValue = false
  lastKey = null
  for _, arg in pairs process.argv
    if nextIsValue
      result[lastKey] = arg
      nextIsValue = false
    else if args[arg]
      lastKey = args[arg]
      nextIsValue = true
  result

version = "shadowsocks-websocket-luvit 0.0.1"
{:version, :parseArgs}
