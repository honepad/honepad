import Foundation

final class Simulation: Harness {
  private var subs: [String: [String]] = [:]
  private var inboxMap: [String: [String]] = [:]
  private var retained: [String: String] = [:]

  private func subscribe(_ topic: String, _ client: String) -> String {
    var clients = subs[topic] ?? []
    if clients.contains(client) {
      return "false"
    }
    clients.append(client)
    subs[topic] = clients
    if let message = retained[topic] {
      inboxMap[client, default: []].append("\(topic):\(message)")
    }
    return "true"
  }

  private func unsubscribe(_ topic: String, _ client: String) -> String {
    guard var clients = subs[topic], let idx = clients.firstIndex(of: client) else {
      return "false"
    }
    clients.remove(at: idx)
    if clients.isEmpty {
      subs.removeValue(forKey: topic)
    } else {
      subs[topic] = clients
    }
    return "true"
  }

  private func publish(_ topic: String, _ message: String) -> String {
    let clients = subs[topic] ?? []
    let payload = "\(topic):\(message)"
    for client in clients {
      inboxMap[client, default: []].append(payload)
    }
    return String(clients.count)
  }

  private func inbox(_ client: String) -> String {
    (inboxMap[client] ?? []).joined(separator: ", ")
  }

  private func listTopics() -> String {
    subs.keys.sorted().joined(separator: ", ")
  }

  private func subscribers(_ topic: String) -> String {
    (subs[topic] ?? []).sorted().joined(separator: ", ")
  }

  private func peek(_ client: String) -> String {
    inboxMap[client]?.first ?? ""
  }

  private func ack(_ client: String, _ n: Int64) -> String {
    guard n > 0, var items = inboxMap[client] else {
      return "invalid_request"
    }
    if n > Int64(items.count) {
      return "invalid_request"
    }
    items.removeFirst(Int(n))
    inboxMap[client] = items
    return String(items.count)
  }

  private func retain(_ topic: String, _ message: String) -> String {
    retained[topic] = message
    return ""
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "subscribe":
      text = try subscribe(argStr(args, 0), argStr(args, 1))
    case "unsubscribe":
      text = try unsubscribe(argStr(args, 0), argStr(args, 1))
    case "publish":
      text = try publish(argStr(args, 0), argStr(args, 1))
    case "inbox":
      text = try inbox(argStr(args, 0))
    case "listTopics":
      text = listTopics()
    case "subscribers":
      text = try subscribers(argStr(args, 0))
    case "peek":
      text = try peek(argStr(args, 0))
    case "ack":
      text = try ack(argStr(args, 0), argI64(args, 1))
    case "retain":
      text = try retain(argStr(args, 0), argStr(args, 1))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
