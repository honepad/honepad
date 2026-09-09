import std/tables

type
  KeyState = ref object
    limit: int64
    window: int64
    windowId: int64
    hasWindow: bool
    used: int64

  Simulation = ref object
    keys: Table[string, KeyState]

proc state(self: Simulation; key: string): KeyState =
  if key notin self.keys:
    self.keys[key] = KeyState(limit: 3, window: 10, windowId: 0, hasWindow: false, used: 0)
  result = self.keys[key]

proc usedAt(item: KeyState; timestamp: int64; persist: bool): int64 =
  let windowId = timestamp div item.window
  if not item.hasWindow or windowId != item.windowId:
    if persist:
      item.windowId = windowId
      item.hasWindow = true
      item.used = 0
    return 0
  result = item.used

proc allowWeighted(self: Simulation; key: string; cost, timestamp: int64): string =
  if cost <= 0:
    return "invalid_request"
  let item = self.state(key)
  discard item.usedAt(timestamp, true)
  if item.used + cost > item.limit:
    return "false"
  item.used += cost
  result = "true"

proc allow(self: Simulation; key: string; timestamp: int64): string =
  result = self.allowWeighted(key, 1, timestamp)

proc configure(self: Simulation; key: string; limit, window: int64): string =
  if limit <= 0 or window <= 0:
    return "invalid_request"
  let item = self.state(key)
  item.limit = limit
  item.window = window
  item.hasWindow = false
  item.used = 0
  result = "true"

proc remaining(self: Simulation; key: string; timestamp: int64): string =
  let item = self.state(key)
  let used = item.usedAt(timestamp, false)
  result = $(item.limit - used)
