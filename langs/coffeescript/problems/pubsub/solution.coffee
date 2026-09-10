class Simulation
  constructor: ->
    @subs = {}
    @inboxMap = {}
    @retained = {}

  subscribe: (topic, client) ->
    clients = if Object.prototype.hasOwnProperty.call(@subs, topic) then @subs[topic] else (@subs[topic] = [])
    return "false" if client in clients
    clients.push client
    if Object.prototype.hasOwnProperty.call(@retained, topic)
      unless Object.prototype.hasOwnProperty.call(@inboxMap, client)
        @inboxMap[client] = []
      @inboxMap[client].push "#{topic}:#{@retained[topic]}"
    "true"

  unsubscribe: (topic, client) ->
    return "false" unless Object.prototype.hasOwnProperty.call(@subs, topic)
    clients = @subs[topic]
    idx = clients.indexOf client
    return "false" if idx < 0
    clients.splice idx, 1
    delete @subs[topic] if clients.length is 0
    "true"

  publish: (topic, message) ->
    clients = if Object.prototype.hasOwnProperty.call(@subs, topic) then @subs[topic] else []
    payload = "#{topic}:#{message}"
    for client in clients
      unless Object.prototype.hasOwnProperty.call(@inboxMap, client)
        @inboxMap[client] = []
      @inboxMap[client].push payload
    String clients.length

  inbox: (client) ->
    items = if Object.prototype.hasOwnProperty.call(@inboxMap, client) then @inboxMap[client] else []
    items.join ", "

  listTopics: ->
    Object.keys(@subs).sort().join ", "

  subscribers: (topic) ->
    clients = if Object.prototype.hasOwnProperty.call(@subs, topic) then @subs[topic].slice() else []
    clients.sort().join ", "

  peek: (client) ->
    items = if Object.prototype.hasOwnProperty.call(@inboxMap, client) then @inboxMap[client] else []
    if items.length then items[0] else ""

  ack: (client, n) ->
    return "invalid_request" if n <= 0 or not Object.prototype.hasOwnProperty.call(@inboxMap, client)
    items = @inboxMap[client]
    return "invalid_request" if n > items.length
    items.splice 0, n
    String items.length

  retain: (topic, message) ->
    @retained[topic] = message
    ""

module.exports = { Simulation }
