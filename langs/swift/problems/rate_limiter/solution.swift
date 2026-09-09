import Foundation

final class KeyState {
  var limit: Int64 = 3
  var window: Int64 = 10
  var windowId: Int64?
  var used: Int64 = 0
}

final class Simulation: Harness {
  private var keys: [String: KeyState] = [:]

  private func state(_ key: String) -> KeyState {
    if let item = keys[key] {
      return item
    }
    let item = KeyState()
    keys[key] = item
    return item
  }

  private func usedAt(_ item: KeyState, _ timestamp: Int64, persist: Bool) -> Int64 {
    let windowId = timestamp / item.window
    if item.windowId == nil || windowId != item.windowId {
      if persist {
        item.windowId = windowId
        item.used = 0
      }
      return 0
    }
    return item.used
  }

  private func allow(_ key: String, _ timestamp: Int64) -> String {
    return allowWeighted(key, 1, timestamp)
  }

  private func configure(_ key: String, _ limit: Int64, _ window: Int64) -> String {
    if limit <= 0 || window <= 0 {
      return "invalid_request"
    }
    let item = state(key)
    item.limit = limit
    item.window = window
    item.windowId = nil
    item.used = 0
    return "true"
  }

  private func remaining(_ key: String, _ timestamp: Int64) -> String {
    let item = state(key)
    let used = usedAt(item, timestamp, persist: false)
    return String(item.limit - used)
  }

  private func allowWeighted(_ key: String, _ cost: Int64, _ timestamp: Int64) -> String {
    if cost <= 0 {
      return "invalid_request"
    }
    let item = state(key)
    _ = usedAt(item, timestamp, persist: true)
    if item.used + cost > item.limit {
      return "false"
    }
    item.used += cost
    return "true"
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "allow":
      text = try allow(argStr(args, 0), argI64(args, 1))
    case "configure":
      text = try configure(argStr(args, 0), argI64(args, 1), argI64(args, 2))
    case "remaining":
      text = try remaining(argStr(args, 0), argI64(args, 1))
    case "allowWeighted":
      text = try allowWeighted(argStr(args, 0), argI64(args, 1), argI64(args, 2))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
