import std/[tables, options, algorithm, strutils]

type
  StoredFile = ref object
    name: string
    size: int64
    owner: string

  Simulation = ref object
    files: Table[string, StoredFile]
    capacity: Table[string, Option[int64]]
    backups: Table[string, Table[string, int64]]

proc ensureAdmin(self: Simulation) =
  if "admin" notin self.capacity:
    self.capacity["admin"] = none(int64)

proc used(self: Simulation; userId: string): int64 =
  result = 0
  for item in self.files.values:
    if item.owner == userId:
      result += item.size

proc remaining(self: Simulation; userId: string): Option[int64] =
  if userId notin self.capacity:
    return none(int64)
  let cap = self.capacity[userId]
  if cap.isNone:
    return none(int64)
  result = some(cap.get - self.used(userId))

proc addFile(self: Simulation; name: string; size: int64): string =
  self.ensureAdmin()
  if name in self.files:
    return "false"
  self.files[name] = StoredFile(name: name, size: size, owner: "admin")
  result = "true"

proc getFileSize(self: Simulation; name: string): string =
  self.ensureAdmin()
  if name notin self.files:
    return ""
  result = $self.files[name].size

proc deleteFile(self: Simulation; name: string): string =
  self.ensureAdmin()
  if name notin self.files:
    return ""
  let size = self.files[name].size
  self.files.del(name)
  result = $size

proc copyFile(self: Simulation; source, dest: string): string =
  self.ensureAdmin()
  if source notin self.files:
    return ""
  let src = self.files[source]
  if source == dest:
    return $src.size
  let destItem = if dest in self.files: self.files[dest] else: nil
  let owner = if destItem.isNil: src.owner else: destItem.owner
  let extra = if destItem.isNil: src.size else: src.size - destItem.size
  let left = self.remaining(owner)
  if left.isSome and extra > left.get:
    return ""
  if destItem.isNil:
    self.files[dest] = StoredFile(name: dest, size: src.size, owner: owner)
  else:
    destItem.size = src.size
  result = $src.size

proc getNLargest(self: Simulation; prefix: string; n: int64): string =
  self.ensureAdmin()
  var matched: seq[StoredFile] = @[]
  for item in self.files.values:
    if item.name.startsWith(prefix):
      matched.add(item)
  matched.sort(
    proc (a, b: StoredFile): int =
      let sizeCmp = cmp(b.size, a.size)
      if sizeCmp != 0:
        return sizeCmp
      result = cmp(a.name, b.name)
  )
  let take = min(int(n), matched.len)
  var parts: seq[string] = @[]
  for i in 0 ..< take:
    parts.add(matched[i].name & "(" & $matched[i].size & ")")
  result = parts.join(", ")

proc addUser(self: Simulation; userId: string; capacity: int64): string =
  self.ensureAdmin()
  if userId in self.capacity:
    return "false"
  self.capacity[userId] = some(capacity)
  result = "true"

proc addFileBy(self: Simulation; userId, name: string; size: int64): string =
  self.ensureAdmin()
  if userId notin self.capacity or name in self.files:
    return ""
  let left = self.remaining(userId)
  if left.isSome and size > left.get:
    return ""
  self.files[name] = StoredFile(name: name, size: size, owner: userId)
  let after = self.remaining(userId)
  result = if after.isNone: "" else: $after.get

proc mergeUser(self: Simulation; userId1, userId2: string): string =
  self.ensureAdmin()
  if userId1 == userId2:
    return ""
  if userId1 notin self.capacity or userId2 notin self.capacity:
    return ""
  let cap1 = self.capacity[userId1]
  let cap2 = self.capacity[userId2]
  if cap1.isNone or cap2.isNone:
    return ""
  self.capacity[userId1] = some(cap1.get + cap2.get)
  for item in self.files.values:
    if item.owner == userId2:
      item.owner = userId1
  self.capacity.del(userId2)
  self.backups.del(userId2)
  let left = self.remaining(userId1)
  result = if left.isNone: "" else: $left.get

proc backupUser(self: Simulation; userId: string): string =
  self.ensureAdmin()
  if userId notin self.capacity:
    return ""
  var snapshot = initTable[string, int64]()
  for item in self.files.values:
    if item.owner == userId:
      snapshot[item.name] = item.size
  self.backups[userId] = snapshot
  result = $snapshot.len

proc restoreUser(self: Simulation; userId: string): string =
  self.ensureAdmin()
  if userId notin self.capacity:
    return ""
  var owned: seq[string] = @[]
  for name, item in self.files:
    if item.owner == userId:
      owned.add(name)
  for name in owned:
    self.files.del(name)
  if userId notin self.backups:
    return "0"
  let snapshot = self.backups[userId]
  var restored = 0
  for name, size in snapshot:
    if name in self.files:
      continue
    let left = self.remaining(userId)
    if left.isSome and size > left.get:
      continue
    self.files[name] = StoredFile(name: name, size: size, owner: userId)
    inc restored
  result = $restored
