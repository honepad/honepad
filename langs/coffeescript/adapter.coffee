fs = require "fs"
path = require "path"

loadClass = (file, className) ->
  mod = require path.resolve(file)
  cls = mod[className] or mod.default or mod
  unless typeof cls is "function"
    throw new Error "missing class " + className
  cls

main = ->
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
  process.stdout.write JSON.stringify({passed, failed}) + "\n"
  process.exit if failed.length then 1 else 0

main()
