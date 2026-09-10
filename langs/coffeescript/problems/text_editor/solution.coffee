class Simulation
  constructor: ->
    @buf = ""
    @pos = 0
    @undoStack = []
    @redoStack = []
    @sel = null
    @clip = ""

  _push: ->
    @undoStack.push [@buf, @pos]
    @redoStack = []
    @sel = null

  insert: (pos, text) ->
    return "invalid_request" if pos < 0 or pos > @buf.length
    @_push()
    @buf = @buf.slice(0, pos) + text + @buf.slice(pos)
    String @buf.length

  erase: (pos, n) ->
    return "invalid_request" if n <= 0 or pos < 0 or pos + n > @buf.length
    @_push()
    deleted = @buf.slice(pos, pos + n)
    @buf = @buf.slice(0, pos) + @buf.slice(pos + n)
    @pos = @buf.length if @pos > @buf.length
    deleted

  getText: ->
    @buf

  length: ->
    String @buf.length

  move: (pos) ->
    return "invalid_request" if pos < 0 or pos > @buf.length
    @pos = pos
    "true"

  typeText: (text) ->
    @_push()
    at = @pos
    @buf = @buf.slice(0, at) + text + @buf.slice(at)
    @pos = at + text.length
    String @buf.length

  cursor: ->
    String @pos

  undo: ->
    return "false" unless @undoStack.length
    @redoStack.push [@buf, @pos]
    snap = @undoStack.pop()
    @buf = snap[0]
    @pos = snap[1]
    @sel = null
    "true"

  redo: ->
    return "false" unless @redoStack.length
    @undoStack.push [@buf, @pos]
    snap = @redoStack.pop()
    @buf = snap[0]
    @pos = snap[1]
    @sel = null
    "true"

  select: (start, end) ->
    return "invalid_request" if start < 0 or end < 0 or start > end or end > @buf.length
    @sel = [start, end]
    "true"

  cut: ->
    return "invalid_request" if not @sel or @sel[0] is @sel[1]
    [start, end] = @sel
    text = @buf.slice(start, end)
    @buf = @buf.slice(0, start) + @buf.slice(end)
    @clip = text
    @pos = start
    @sel = null
    text

  copySel: ->
    return "invalid_request" if not @sel or @sel[0] is @sel[1]
    [start, end] = @sel
    @clip = @buf.slice(start, end)
    @clip

  paste: ->
    return "invalid_request" if @clip is ""
    at = @pos
    @buf = @buf.slice(0, at) + @clip + @buf.slice(at)
    @pos = at + @clip.length
    String @buf.length

module.exports = { Simulation }
