class InMemoryDatabase
  constructor: ->
    @database = {}
    @backupTimestamps = []
    @backupStates = []

  _setInternal: (key, field, value, expiry) ->
    @database[key] = {} unless @database[key]
    @database[key][field] = [value, expiry]
    ""

  _isAlive: (key, field, timestamp) ->
    return false unless @database[key] and field of @database[key]
    expiry = @database[key][field][1]
    return true if expiry is null or expiry is undefined
    timestamp < expiry

  set: (key, field, value) ->
    @_setInternal key, field, value, null

  get: (key, field) ->
    return "" unless @database[key] and field of @database[key]
    @database[key][field][0]

  delete: (key, field) ->
    return "false" unless @database[key] and field of @database[key]
    delete @database[key][field]
    "true"

  scan: (key) ->
    return "" unless @database[key]
    Object.keys(@database[key]).sort().map((field) =>
      "#{field}(#{@database[key][field][0]})"
    ).join ", "

  scanByPrefix: (key, prefix) ->
    return "" unless @database[key]
    Object.keys(@database[key]).filter((field) ->
      field.startsWith prefix
    ).sort().map((field) =>
      "#{field}(#{@database[key][field][0]})"
    ).join ", "

  setAt: (key, field, value, _timestamp) ->
    @_setInternal key, field, value, null

  setAtWithTtl: (key, field, value, timestamp, ttl) ->
    @_setInternal key, field, value, timestamp + ttl

  deleteAt: (key, field, timestamp) ->
    return "false" unless @_isAlive key, field, timestamp
    delete @database[key][field]
    "true"

  getAt: (key, field, timestamp) ->
    return "" unless @_isAlive key, field, timestamp
    @database[key][field][0]

  scanAt: (key, timestamp) ->
    return "" unless @database[key]
    Object.keys(@database[key]).filter((field) =>
      @_isAlive key, field, timestamp
    ).sort().map((field) =>
      "#{field}(#{@database[key][field][0]})"
    ).join ", "

  scanByPrefixAt: (key, prefix, timestamp) ->
    return "" unless @database[key]
    Object.keys(@database[key]).filter((field) =>
      field.startsWith(prefix) and @_isAlive key, field, timestamp
    ).sort().map((field) =>
      "#{field}(#{@database[key][field][0]})"
    ).join ", "

  backup: (timestamp) ->
    state = {}
    for key in Object.keys(@database)
      for field in Object.keys(@database[key])
        if @_isAlive key, field, timestamp
          [value, expiry] = @database[key][field]
          remaining = if expiry is null or expiry is undefined then null else expiry - timestamp
          state[key] = {} unless state[key]
          state[key][field] = [value, remaining]
    @backupTimestamps.push timestamp
    @backupStates.push state
    String Object.keys(state).length

  restore: (timestamp, timestampToRestore) ->
    idx = -1
    i = 0
    while i < @backupTimestamps.length
      idx = i if @backupTimestamps[i] <= timestampToRestore
      i += 1
    backup = @backupStates[idx]
    @database = {}
    for key in Object.keys(backup)
      for field in Object.keys(backup[key])
        [value, remaining] = backup[key][field]
        expiry = if remaining is null or remaining is undefined then null else timestamp + remaining
        @_setInternal key, field, value, expiry
    ""

module.exports = { InMemoryDatabase }
