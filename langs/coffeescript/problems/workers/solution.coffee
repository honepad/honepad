class Worker
  constructor: (workerId, position, compensation) ->
    @workerId = workerId
    @position = position
    @compensation = compensation
    @inOffice = false
    @enteredAt = null
    @finished = []
    @pendingPromo = null

  totalTime: ->
    @finished.reduce (sum, [start, end]) ->
      sum + (end - start)
    , 0

  positionTime: (position) ->
    @finished.filter(([, , , pos]) ->
      pos is position
    ).reduce (sum, [start, end]) ->
      sum + (end - start)
    , 0

  applyPromoOnEnter: (timestamp) ->
    return if @pendingPromo is null
    [newPos, newComp, startTs] = @pendingPromo
    if timestamp >= startTs
      @position = newPos
      @compensation = newComp
      @pendingPromo = null

class Simulation
  constructor: ->
    @workers = {}

  addWorker: (workerId, position, compensation) ->
    return "false" if Object.prototype.hasOwnProperty.call(@workers, workerId)
    @workers[workerId] = new Worker workerId, position, compensation
    "true"

  register: (workerId, timestamp) ->
    worker = @workers[workerId]
    return "invalid_request" unless worker
    if worker.inOffice
      worker.finished.push [
        worker.enteredAt
        timestamp
        worker.compensation
        worker.position
      ]
      worker.inOffice = false
      worker.enteredAt = null
      return "registered"
    worker.applyPromoOnEnter timestamp
    worker.inOffice = true
    worker.enteredAt = timestamp
    "registered"

  get: (workerId) ->
    worker = @workers[workerId]
    return "" unless worker
    String worker.totalTime()

  topNWorkers: (n, position) ->
    matched = Object.values(@workers).filter (w) ->
      w.position is position
    matched.sort (a, b) ->
      b.positionTime(position) - a.positionTime(position) or
        (if a.workerId < b.workerId then -1 else if a.workerId > b.workerId then 1 else 0)
    matched.slice(0, n).map((w) ->
      "#{w.workerId}(#{w.positionTime(position)})"
    ).join ", "

  promote: (workerId, newPosition, newCompensation, startTimestamp) ->
    worker = @workers[workerId]
    return "invalid_request" if not worker or worker.pendingPromo isnt null
    worker.pendingPromo = [newPosition, newCompensation, startTimestamp]
    "success"

  calcSalary: (workerId, startTimestamp, endTimestamp) ->
    worker = @workers[workerId]
    return "" unless worker
    total = 0
    for [sessionStart, sessionEnd, rate] in worker.finished
      lo = Math.max sessionStart, startTimestamp
      hi = Math.min sessionEnd, endTimestamp
      total += (hi - lo) * rate if hi > lo
    String total

module.exports = { Simulation }
