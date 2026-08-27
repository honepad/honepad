import std/[tables, options, algorithm, strutils]

type
  FieldVal = tuple[value: string, expiry: Option[int64]]
  InMemoryDatabase = ref object
    database: Table[string, Table[string, FieldVal]]
    backupTimestamps: seq[int64]
    backupStates: seq[Table[string, Table[string, FieldVal]]]

proc setInternal(
    self: InMemoryDatabase; key, field, value: string; expiry: Option[int64]
): string =
  if key notin self.database:
    self.database[key] = initTable[string, FieldVal]()
  self.database[key][field] = (value, expiry)
  result = ""

proc isAlive(self: InMemoryDatabase; key, field: string; timestamp: int64): bool =
  if key notin self.database or field notin self.database[key]:
    return false
  let expiry = self.database[key][field].expiry
  if expiry.isNone:
    return true
  result = timestamp < expiry.get

proc set(self: InMemoryDatabase; key, field, value: string): string =
  self.setInternal(key, field, value, none(int64))

proc get(self: InMemoryDatabase; key, field: string): string =
  if key notin self.database or field notin self.database[key]:
    return ""
  result = self.database[key][field].value

proc delete(self: InMemoryDatabase; key, field: string): string =
  if key notin self.database or field notin self.database[key]:
    return "false"
  self.database[key].del(field)
  result = "true"

proc scan(self: InMemoryDatabase; key: string): string =
  if key notin self.database:
    return ""
  var items: seq[(string, FieldVal)] = @[]
  for field, value in self.database[key]:
    items.add((field, value))
  items.sort(proc (a, b: (string, FieldVal)): int = cmp(a[0], b[0]))
  var parts: seq[string] = @[]
  for (field, value) in items:
    parts.add(field & "(" & value.value & ")")
  result = parts.join(", ")

proc scanByPrefix(self: InMemoryDatabase; key, prefix: string): string =
  if key notin self.database:
    return ""
  var items: seq[(string, FieldVal)] = @[]
  for field, value in self.database[key]:
    if field.startsWith(prefix):
      items.add((field, value))
  items.sort(proc (a, b: (string, FieldVal)): int = cmp(a[0], b[0]))
  var parts: seq[string] = @[]
  for (field, value) in items:
    parts.add(field & "(" & value.value & ")")
  result = parts.join(", ")

proc setAt(
    self: InMemoryDatabase; key, field, value: string; timestamp: int64
): string =
  discard timestamp
  self.setInternal(key, field, value, none(int64))

proc setAtWithTtl(
    self: InMemoryDatabase; key, field, value: string; timestamp, ttl: int64
): string =
  self.setInternal(key, field, value, some(timestamp + ttl))

proc deleteAt(self: InMemoryDatabase; key, field: string; timestamp: int64): string =
  if not self.isAlive(key, field, timestamp):
    return "false"
  self.database[key].del(field)
  result = "true"

proc getAt(self: InMemoryDatabase; key, field: string; timestamp: int64): string =
  if not self.isAlive(key, field, timestamp):
    return ""
  result = self.database[key][field].value

proc scanAt(self: InMemoryDatabase; key: string; timestamp: int64): string =
  if key notin self.database:
    return ""
  var items: seq[(string, string)] = @[]
  for field, value in self.database[key]:
    if self.isAlive(key, field, timestamp):
      items.add((field, value.value))
  items.sort(proc (a, b: (string, string)): int = cmp(a[0], b[0]))
  var parts: seq[string] = @[]
  for (field, value) in items:
    parts.add(field & "(" & value & ")")
  result = parts.join(", ")

proc scanByPrefixAt(
    self: InMemoryDatabase; key, prefix: string; timestamp: int64
): string =
  if key notin self.database:
    return ""
  var items: seq[(string, string)] = @[]
  for field, value in self.database[key]:
    if field.startsWith(prefix) and self.isAlive(key, field, timestamp):
      items.add((field, value.value))
  items.sort(proc (a, b: (string, string)): int = cmp(a[0], b[0]))
  var parts: seq[string] = @[]
  for (field, value) in items:
    parts.add(field & "(" & value & ")")
  result = parts.join(", ")

proc backup(self: InMemoryDatabase; timestamp: int64): string =
  var state = initTable[string, Table[string, FieldVal]]()
  for key, fields in self.database:
    for field, value in fields:
      if self.isAlive(key, field, timestamp):
        let remaining =
          if value.expiry.isNone:
            none(int64)
          else:
            some(value.expiry.get - timestamp)
        if key notin state:
          state[key] = initTable[string, FieldVal]()
        state[key][field] = (value.value, remaining)
  self.backupTimestamps.add(timestamp)
  self.backupStates.add(state)
  result = $state.len

proc restore(
    self: InMemoryDatabase; timestamp, timestampToRestore: int64
): string =
  var idx = self.backupTimestamps.len
  for i, ts in self.backupTimestamps:
    if ts > timestampToRestore:
      idx = i
      break
  dec idx
  let backupState = self.backupStates[idx]
  self.database = initTable[string, Table[string, FieldVal]]()
  for key, fields in backupState:
    for field, value in fields:
      let expiry =
        if value.expiry.isNone:
          none(int64)
        else:
          some(timestamp + value.expiry.get)
      discard self.setInternal(key, field, value.value, expiry)
  result = ""
