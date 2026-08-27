class Simulation
  constructor: ->
    @files = {}
    @capacity = {admin: null}
    @backups = {}

  _used: (userId) ->
    Object.values(@files).filter((item) ->
      item.owner is userId
    ).reduce (sum, item) ->
      sum + item.size
    , 0

  _remaining: (userId) ->
    cap = @capacity[userId]
    return null if cap is null or cap is undefined
    cap - @_used userId

  addFile: (name, size) ->
    return "false" if @files[name]
    @files[name] = {name, size, owner: "admin"}
    "true"

  getFileSize: (name) ->
    if @files[name] then String(@files[name].size) else ""

  deleteFile: (name) ->
    return "" unless @files[name]
    size = @files[name].size
    delete @files[name]
    String size

  getNLargest: (prefix, n) ->
    matched = Object.values(@files).filter (item) ->
      item.name.startsWith prefix
    matched.sort (a, b) ->
      b.size - a.size or (if a.name < b.name then -1 else if a.name > b.name then 1 else 0)
    matched.slice(0, n).map((item) ->
      "#{item.name}(#{item.size})"
    ).join ", "

  addUser: (userId, capacity) ->
    return "false" if Object.prototype.hasOwnProperty.call(@capacity, userId)
    @capacity[userId] = capacity
    "true"

  addFileBy: (userId, name, size) ->
    unless Object.prototype.hasOwnProperty.call(@capacity, userId) and not @files[name]
      return ""
    remaining = @_remaining userId
    return "" if remaining isnt null and size > remaining
    @files[name] = {name, size, owner: userId}
    left = @_remaining userId
    if left is null then "" else String(left)

  mergeUser: (userId1, userId2) ->
    return "" if userId1 is userId2
    unless Object.prototype.hasOwnProperty.call(@capacity, userId1) and
        Object.prototype.hasOwnProperty.call(@capacity, userId2)
      return ""
    return "" if @capacity[userId1] is null or @capacity[userId2] is null
    @capacity[userId1] += @capacity[userId2]
    for item in Object.values(@files)
      item.owner = userId1 if item.owner is userId2
    delete @capacity[userId2]
    delete @backups[userId2]
    String @_remaining userId1

  backupUser: (userId) ->
    return "" unless Object.prototype.hasOwnProperty.call(@capacity, userId)
    snap = {}
    for item in Object.values(@files)
      snap[item.name] = item.size if item.owner is userId
    @backups[userId] = snap
    String Object.keys(snap).length

  restoreUser: (userId) ->
    return "" unless Object.prototype.hasOwnProperty.call(@capacity, userId)
    for name in Object.keys(@files)
      delete @files[name] if @files[name].owner is userId
    snap = @backups[userId]
    return "0" unless snap
    restored = 0
    for name, size of snap
      continue if @files[name]
      remaining = @_remaining userId
      continue if remaining isnt null and size > remaining
      @files[name] = {name, size, owner: userId}
      restored += 1
    String restored

module.exports = { Simulation }
