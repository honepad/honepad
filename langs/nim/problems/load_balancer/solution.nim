import std/tables

type
  Backend = ref object
    backendId: string
    health: bool
    weight: int64
    inflight: int64

  Simulation = ref object
    backends: seq[Backend]
    byId: Table[string, Backend]
    cursor: int64
    stickyMap: Table[string, string]
    useLeast: bool

proc addBackend(self: Simulation; backendId: string): string =
  if backendId in self.byId:
    return "false"
  let item = Backend(backendId: backendId, health: true, weight: 1, inflight: 0)
  self.backends.add(item)
  self.byId[backendId] = item
  result = "true"

proc resetCycle(self: Simulation) =
  self.cursor = 0
  self.useLeast = false
  for item in self.backends:
    item.inflight = 0

proc setHealth(self: Simulation; backendId: string; flag: int64): string =
  if backendId notin self.byId or (flag != 0 and flag != 1):
    return "invalid_request"
  self.byId[backendId].health = flag == 1
  self.resetCycle()
  result = "true"

proc setWeight(self: Simulation; backendId: string; weight: int64): string =
  if backendId notin self.byId or weight <= 0:
    return "invalid_request"
  self.byId[backendId].weight = weight
  self.resetCycle()
  result = "true"

proc tickets(items: seq[Backend]): seq[Backend] =
  result = @[]
  for item in items:
    for _ in 1 .. item.weight:
      result.add(item)

proc pick(self: Simulation): Backend =
  var healthy: seq[Backend] = @[]
  for item in self.backends:
    if item.health:
      healthy.add(item)
  if healthy.len == 0:
    return nil
  var pool = healthy
  if self.useLeast:
    var least = healthy[0].inflight
    for item in healthy:
      if item.inflight < least:
        least = item.inflight
    pool = @[]
    for item in healthy:
      if item.inflight == least:
        pool.add(item)
  let ticketList = tickets(pool)
  if ticketList.len == 0:
    return nil
  result = ticketList[int(self.cursor mod int64(ticketList.len))]
  self.cursor += 1

proc take(self: Simulation): string =
  let item = self.pick()
  if item == nil:
    return ""
  item.inflight += 1
  result = item.backendId

proc route(self: Simulation): string =
  result = self.take()

proc sticky(self: Simulation; clientId: string): string =
  if clientId in self.stickyMap:
    let bound = self.stickyMap[clientId]
    if bound in self.byId:
      let item = self.byId[bound]
      if item.health:
        item.inflight += 1
        return item.backendId
  let chosen = self.take()
  if chosen.len > 0:
    self.stickyMap[clientId] = chosen
  result = chosen

proc done(self: Simulation; backendId: string): string =
  if backendId notin self.byId or self.byId[backendId].inflight <= 0:
    return "invalid_request"
  self.byId[backendId].inflight -= 1
  self.useLeast = true
  result = "true"
