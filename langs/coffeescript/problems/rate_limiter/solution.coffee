class KeyState
  constructor: ->
    @limit = 3
    @window = 10
    @windowId = null
    @used = 0

class Simulation
  constructor: ->
    @keys = {}

  _state: (key) ->
    item = @keys[key]
    unless item
      item = new KeyState
      @keys[key] = item
    item

  _usedAt: (item, timestamp, persist) ->
    windowId = Math.floor timestamp / item.window
    if item.windowId is null or windowId isnt item.windowId
      if persist
        item.windowId = windowId
        item.used = 0
      return 0
    item.used

  allow: (key, timestamp) ->
    @allowWeighted key, 1, timestamp

  configure: (key, limit, window) ->
    return "invalid_request" if limit <= 0 or window <= 0
    item = @_state key
    item.limit = limit
    item.window = window
    item.windowId = null
    item.used = 0
    "true"

  remaining: (key, timestamp) ->
    item = @_state key
    used = @_usedAt item, timestamp, false
    String item.limit - used

  allowWeighted: (key, cost, timestamp) ->
    return "invalid_request" if cost <= 0
    item = @_state key
    @_usedAt item, timestamp, true
    return "false" if item.used + cost > item.limit
    item.used += cost
    "true"

module.exports = { Simulation }
