import Foundation

final class Backend {
  let backendId: String
  var health = true
  var weight: Int64 = 1
  var inflight: Int64 = 0

  init(_ backendId: String) {
    self.backendId = backendId
  }
}

final class Simulation: Harness {
  private var backends: [Backend] = []
  private var byId: [String: Backend] = [:]
  private var cursor: Int64 = 0
  private var stickyMap: [String: String] = [:]
  private var useLeast = false

  private func resetCycle() {
    cursor = 0
    useLeast = false
    for item in backends {
      item.inflight = 0
    }
  }

  private func tickets(_ items: [Backend]) -> [Backend] {
    var out: [Backend] = []
    for item in items {
      for _ in 0..<Int(item.weight) {
        out.append(item)
      }
    }
    return out
  }

  private func pick() -> Backend? {
    let healthy = backends.filter { $0.health }
    if healthy.isEmpty {
      return nil
    }
    var pool = healthy
    if useLeast {
      let least = healthy.map { $0.inflight }.min() ?? 0
      pool = healthy.filter { $0.inflight == least }
    }
    let ticketList = tickets(pool)
    if ticketList.isEmpty {
      return nil
    }
    let chosen = ticketList[Int(cursor) % ticketList.count]
    cursor += 1
    return chosen
  }

  private func take() -> String {
    guard let item = pick() else {
      return ""
    }
    item.inflight += 1
    return item.backendId
  }

  private func addBackend(_ backendId: String) -> String {
    if byId[backendId] != nil {
      return "false"
    }
    let item = Backend(backendId)
    backends.append(item)
    byId[backendId] = item
    return "true"
  }

  private func setHealth(_ backendId: String, _ flag: Int64) -> String {
    guard let item = byId[backendId], flag == 0 || flag == 1 else {
      return "invalid_request"
    }
    item.health = flag == 1
    resetCycle()
    return "true"
  }

  private func setWeight(_ backendId: String, _ weight: Int64) -> String {
    guard let item = byId[backendId], weight > 0 else {
      return "invalid_request"
    }
    item.weight = weight
    resetCycle()
    return "true"
  }

  private func route() -> String {
    return take()
  }

  private func sticky(_ clientId: String) -> String {
    if let bound = stickyMap[clientId], let item = byId[bound], item.health {
      item.inflight += 1
      return item.backendId
    }
    let chosen = take()
    if !chosen.isEmpty {
      stickyMap[clientId] = chosen
    }
    return chosen
  }

  private func done(_ backendId: String) -> String {
    guard let item = byId[backendId], item.inflight > 0 else {
      return "invalid_request"
    }
    item.inflight -= 1
    useLeast = true
    return "true"
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "addBackend":
      text = try addBackend(argStr(args, 0))
    case "route":
      text = route()
    case "setHealth":
      text = try setHealth(argStr(args, 0), argI64(args, 1))
    case "setWeight":
      text = try setWeight(argStr(args, 0), argI64(args, 1))
    case "sticky":
      text = try sticky(argStr(args, 0))
    case "done":
      text = try done(argStr(args, 0))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
