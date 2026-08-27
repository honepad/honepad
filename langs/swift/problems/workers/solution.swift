import Foundation

struct WorkSession {
  var start: Int64
  var end: Int64
  var rate: Int64
  var position: String
}

struct Promo {
  var position: String
  var compensation: Int64
  var startTimestamp: Int64
}

final class Worker {
  var workerId: String
  var position: String
  var compensation: Int64
  var inOffice = false
  var enteredAt: Int64?
  var finished: [WorkSession] = []
  var pendingPromo: Promo?

  init(workerId: String, position: String, compensation: Int64) {
    self.workerId = workerId
    self.position = position
    self.compensation = compensation
  }

  func totalTime() -> Int64 {
    finished.reduce(0) { $0 + ($1.end - $1.start) }
  }

  func positionTime(_ pos: String) -> Int64 {
    finished.reduce(0) { sum, session in
      session.position == pos ? sum + (session.end - session.start) : sum
    }
  }

  func applyPromoOnEnter(_ timestamp: Int64) {
    guard let promo = pendingPromo else {
      return
    }
    if timestamp >= promo.startTimestamp {
      position = promo.position
      compensation = promo.compensation
      pendingPromo = nil
    }
  }
}

final class Simulation: Harness {
  private var workers: [String: Worker] = [:]

  private func addWorker(_ workerId: String, _ position: String, _ compensation: Int64) -> String {
    if workers[workerId] != nil {
      return "false"
    }
    workers[workerId] = Worker(workerId: workerId, position: position, compensation: compensation)
    return "true"
  }

  private func registerWorker(_ workerId: String, _ timestamp: Int64) -> String {
    guard let worker = workers[workerId] else {
      return "invalid_request"
    }
    if worker.inOffice {
      worker.finished.append(
        WorkSession(
          start: worker.enteredAt!,
          end: timestamp,
          rate: worker.compensation,
          position: worker.position
        )
      )
      worker.inOffice = false
      worker.enteredAt = nil
      return "registered"
    }
    worker.applyPromoOnEnter(timestamp)
    worker.inOffice = true
    worker.enteredAt = timestamp
    return "registered"
  }

  private func get(_ workerId: String) -> String {
    guard let worker = workers[workerId] else {
      return ""
    }
    return String(worker.totalTime())
  }

  private func topNWorkers(_ n: Int64, _ position: String) -> String {
    var matched = workers.values.filter { $0.position == position }
    matched.sort { left, right in
      let timeLeft = left.positionTime(position)
      let timeRight = right.positionTime(position)
      if timeLeft != timeRight {
        return timeRight < timeLeft
      }
      return left.workerId < right.workerId
    }
    if n < Int64(matched.count) {
      matched = Array(matched.prefix(Int(n)))
    }
    return matched.enumerated().map { index, worker in
      let lead = index > 0 ? ", " : ""
      return "\(lead)\(worker.workerId)(\(worker.positionTime(position)))"
    }.joined()
  }

  private func promote(
    _ workerId: String,
    _ newPosition: String,
    _ newCompensation: Int64,
    _ startTimestamp: Int64
  ) -> String {
    guard let worker = workers[workerId], worker.pendingPromo == nil else {
      return "invalid_request"
    }
    worker.pendingPromo = Promo(
      position: newPosition,
      compensation: newCompensation,
      startTimestamp: startTimestamp
    )
    return "success"
  }

  private func calcSalary(_ workerId: String, _ startTimestamp: Int64, _ endTimestamp: Int64)
    -> String
  {
    guard let worker = workers[workerId] else {
      return ""
    }
    var total: Int64 = 0
    for session in worker.finished {
      let lo = max(session.start, startTimestamp)
      let hi = min(session.end, endTimestamp)
      if hi > lo {
        total += (hi - lo) * session.rate
      }
    }
    return String(total)
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "addWorker":
      text = try addWorker(argStr(args, 0), argStr(args, 1), argI64(args, 2))
    case "register":
      text = try registerWorker(argStr(args, 0), argI64(args, 1))
    case "get":
      text = try get(argStr(args, 0))
    case "topNWorkers":
      text = try topNWorkers(argI64(args, 0), argStr(args, 1))
    case "promote":
      text = try promote(argStr(args, 0), argStr(args, 1), argI64(args, 2), argI64(args, 3))
    case "calcSalary":
      text = try calcSalary(argStr(args, 0), argI64(args, 1), argI64(args, 2))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
