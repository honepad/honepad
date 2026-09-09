class Backend
  constructor: (@backendId) ->
    @health = true
    @weight = 1
    @inflight = 0

class Simulation
  constructor: ->
    @backends = []
    @byId = {}
    @cursor = 0
    @stickyMap = {}
    @useLeast = false

  addBackend: (backendId) ->
    return "false" if Object.prototype.hasOwnProperty.call(@byId, backendId)
    item = new Backend backendId
    @backends.push item
    @byId[backendId] = item
    "true"

  setHealth: (backendId, flag) ->
    item = if Object.prototype.hasOwnProperty.call(@byId, backendId) then @byId[backendId] else null
    return "invalid_request" if not item or (flag isnt 0 and flag isnt 1)
    item.health = flag is 1
    @_resetCycle()
    "true"

  setWeight: (backendId, weight) ->
    item = if Object.prototype.hasOwnProperty.call(@byId, backendId) then @byId[backendId] else null
    return "invalid_request" if not item or weight <= 0
    item.weight = weight
    @_resetCycle()
    "true"

  _resetCycle: ->
    @cursor = 0
    @useLeast = false
    item.inflight = 0 for item in @backends

  _tickets: (items) ->
    tickets = []
    for item in items
      tickets.push item for _ in [0...item.weight]
    tickets

  _pick: ->
    healthy = (item for item in @backends when item.health)
    return null if healthy.length is 0
    pool = healthy
    if @useLeast
      least = healthy[0].inflight
      least = item.inflight for item in healthy when item.inflight < least
      pool = (item for item in healthy when item.inflight is least)
    tickets = @_tickets pool
    return null if tickets.length is 0
    chosen = tickets[@cursor % tickets.length]
    @cursor += 1
    chosen

  _take: ->
    item = @_pick()
    return "" unless item
    item.inflight += 1
    item.backendId

  route: ->
    @_take()

  sticky: (clientId) ->
    bound = if Object.prototype.hasOwnProperty.call(@stickyMap, clientId) then @stickyMap[clientId] else null
    item = if bound and Object.prototype.hasOwnProperty.call(@byId, bound) then @byId[bound] else null
    if item and item.health
      item.inflight += 1
      return item.backendId
    chosen = @_take()
    @stickyMap[clientId] = chosen if chosen
    chosen

  done: (backendId) ->
    item = if Object.prototype.hasOwnProperty.call(@byId, backendId) then @byId[backendId] else null
    return "invalid_request" if not item or item.inflight <= 0
    item.inflight -= 1
    @useLeast = true
    "true"

module.exports = { Simulation }
