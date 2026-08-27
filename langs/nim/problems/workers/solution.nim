import std/[tables, options, algorithm, strutils]

type
  Worker = ref object
    workerId: string
    position: string
    compensation: int64
    inOffice: bool
    enteredAt: Option[int64]
    finished: seq[(int64, int64, int64, string)]
    pendingPromo: Option[(string, int64, int64)]

  Simulation = ref object
    workers: Table[string, Worker]

proc totalTime(worker: Worker): int64 =
  result = 0
  for (startTs, endTs, _, _) in worker.finished:
    result += endTs - startTs

proc positionTime(worker: Worker; position: string): int64 =
  result = 0
  for (startTs, endTs, _, pos) in worker.finished:
    if pos == position:
      result += endTs - startTs

proc applyPromoOnEnter(worker: Worker; timestamp: int64) =
  if worker.pendingPromo.isNone:
    return
  let (newPos, newComp, startTs) = worker.pendingPromo.get
  if timestamp >= startTs:
    worker.position = newPos
    worker.compensation = newComp
    worker.pendingPromo = none((string, int64, int64))

proc addWorker(
    self: Simulation; workerId, position: string; compensation: int64
): string =
  if workerId in self.workers:
    return "false"
  self.workers[workerId] = Worker(
    workerId: workerId,
    position: position,
    compensation: compensation,
    inOffice: false,
    enteredAt: none(int64),
    finished: @[],
    pendingPromo: none((string, int64, int64)),
  )
  result = "true"

proc register(self: Simulation; workerId: string; timestamp: int64): string =
  if workerId notin self.workers:
    return "invalid_request"
  let worker = self.workers[workerId]
  if worker.inOffice:
    worker.finished.add(
      (worker.enteredAt.get, timestamp, worker.compensation, worker.position)
    )
    worker.inOffice = false
    worker.enteredAt = none(int64)
    return "registered"
  worker.applyPromoOnEnter(timestamp)
  worker.inOffice = true
  worker.enteredAt = some(timestamp)
  result = "registered"

proc get(self: Simulation; workerId: string): string =
  if workerId notin self.workers:
    return ""
  result = $self.workers[workerId].totalTime()

proc topNWorkers(self: Simulation; n: int64; position: string): string =
  var matched: seq[Worker] = @[]
  for worker in self.workers.values:
    if worker.position == position:
      matched.add(worker)
  matched.sort(
    proc (a, b: Worker): int =
      let timeCmp = cmp(b.positionTime(position), a.positionTime(position))
      if timeCmp != 0:
        return timeCmp
      result = cmp(a.workerId, b.workerId)
  )
  let take = min(int(n), matched.len)
  var parts: seq[string] = @[]
  for i in 0 ..< take:
    let worker = matched[i]
    parts.add(worker.workerId & "(" & $worker.positionTime(position) & ")")
  result = parts.join(", ")

proc promote(
    self: Simulation;
    workerId, newPosition: string;
    newCompensation, startTimestamp: int64;
): string =
  if workerId notin self.workers:
    return "invalid_request"
  let worker = self.workers[workerId]
  if worker.pendingPromo.isSome:
    return "invalid_request"
  worker.pendingPromo = some((newPosition, newCompensation, startTimestamp))
  result = "success"

proc calcSalary(
    self: Simulation; workerId: string; startTimestamp, endTimestamp: int64
): string =
  if workerId notin self.workers:
    return ""
  var total: int64 = 0
  for (sessionStart, sessionEnd, rate, _) in self.workers[workerId].finished:
    let lo = max(sessionStart, startTimestamp)
    let hi = min(sessionEnd, endTimestamp)
    if hi > lo:
      total += (hi - lo) * rate
  result = $total
