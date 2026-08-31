fs = require "fs"
path = require "path"

loadClass = (file, className) ->
  mod = require path.resolve(file)
  cls = mod[className] or mod.default or mod
  unless typeof cls is "function"
    throw new Error "missing class " + className
  cls

byteLength = (chunk, encoding) ->
  return 0 unless chunk?
  return chunk.length if Buffer.isBuffer chunk
  Buffer.byteLength String(chunk), if typeof encoding is "string" then encoding else undefined

main = ->
  origWrite = process.stdout.write.bind process.stdout
  process.stdout.write = (chunk, encoding, cb) ->
    if typeof encoding is "function"
      cb = encoding
      encoding = undefined
    if typeof cb is "function"
      process.nextTick cb
    true
  origFsWriteSync = fs.writeSync
  fs.writeSync = (fd, chunk, offset, length, position) ->
    if fd is 1
      if Buffer.isBuffer(chunk) and typeof length is "number"
        return length
      return byteLength chunk, offset
    origFsWriteSync.apply fs, arguments
  origFsWrite = fs.write
  fs.write = (fd, chunk) ->
    if fd is 1
      args = Array.prototype.slice.call arguments, 1
      cb = if typeof args[args.length - 1] is "function" then args.pop() else undefined
      written = byteLength chunk, if typeof args[0] is "string" then undefined else args[1]
      if typeof cb is "function"
        process.nextTick -> cb null, written, chunk
      return
    origFsWrite.apply fs, arguments
  file = process.argv[2]
  className = process.argv[3]
  casesPath = process.argv[4]
  Cls = loadClass file, className
  cases = JSON.parse fs.readFileSync(casesPath, "utf8")
  failed = []
  passed = 0
  for c in cases
    obj = new Cls()
    ok = true
    i = 0
    while i < c.calls.length
      call = c.calls[i]
      name = if call.m.includes "_"
        call.m.split("_").map((p, idx) ->
          if idx is 0 then p else p[0].toUpperCase() + p.slice(1)
        ).join ""
      else
        call.m
      fn = obj[name]
      try
        actual = fn.apply obj, call.a
      catch err
        failed.push
          case: c.id
          index: i
          method: call.m
          expected: call.e
          actual: "exc:" + err.name
        ok = false
        break
      exp = call.e
      same = JSON.stringify(actual) is JSON.stringify(exp)
      unless same
        failed.push
          case: c.id
          index: i
          method: call.m
          expected: exp
          actual: actual
        ok = false
        break
      i += 1
    passed += 1 if ok
  origWrite JSON.stringify({passed, failed}) + "\n"
  process.exit if failed.length then 1 else 0

main()
