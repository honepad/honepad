import Foundation

struct StoredFile {
  var name: String
  var size: Int64
  var owner: String
}

final class Simulation: Harness {
  private var files: [String: StoredFile] = [:]
  private var fileOrder: [String] = []
  private var capacity: [String: Int64?] = ["admin": nil]
  private var backups: [String: [(String, Int64)]] = [:]

  private func used(_ userId: String) -> Int64 {
    files.values.reduce(0) { sum, item in
      item.owner == userId ? sum + item.size : sum
    }
  }

  private func remaining(_ userId: String) -> Int64? {
    guard let wrapped = capacity[userId], let cap = wrapped else {
      return nil
    }
    return cap - used(userId)
  }

  private func addFile(_ name: String, _ size: Int64) -> String {
    if files[name] != nil {
      return "false"
    }
    files[name] = StoredFile(name: name, size: size, owner: "admin")
    fileOrder.append(name)
    return "true"
  }

  private func getFileSize(_ name: String) -> String {
    guard let item = files[name] else {
      return ""
    }
    return String(item.size)
  }

  private func deleteFile(_ name: String) -> String {
    guard let item = files[name] else {
      return ""
    }
    files[name] = nil
    fileOrder.removeAll { $0 == name }
    return String(item.size)
  }

  private func getNLargest(_ prefix: String, _ n: Int64) -> String {
    var matched = files.values.filter { $0.name.hasPrefix(prefix) }
    matched.sort { left, right in
      if left.size != right.size {
        return right.size < left.size
      }
      return left.name < right.name
    }
    if n < Int64(matched.count) {
      matched = Array(matched.prefix(Int(n)))
    }
    return matched.enumerated().map { index, item in
      let lead = index > 0 ? ", " : ""
      return "\(lead)\(item.name)(\(item.size))"
    }.joined()
  }

  private func addUser(_ userId: String, _ cap: Int64) -> String {
    if capacity[userId] != nil {
      return "false"
    }
    capacity[userId] = cap
    return "true"
  }

  private func addFileBy(_ userId: String, _ name: String, _ size: Int64) -> String {
    if capacity[userId] == nil || files[name] != nil {
      return ""
    }
    if let left = remaining(userId), size > left {
      return ""
    }
    files[name] = StoredFile(name: name, size: size, owner: userId)
    fileOrder.append(name)
    if let after = remaining(userId) {
      return String(after)
    }
    return ""
  }

  private func mergeUser(_ userId1: String, _ userId2: String) -> String {
    if userId1 == userId2 {
      return ""
    }
    guard let cap1Box = capacity[userId1], let cap1 = cap1Box,
      let cap2Box = capacity[userId2], let cap2 = cap2Box
    else {
      return ""
    }
    capacity[userId1] = cap1 + cap2
    for name in files.keys {
      if files[name]?.owner == userId2 {
        files[name]?.owner = userId1
      }
    }
    capacity[userId2] = nil
    backups[userId2] = nil
    if let left = remaining(userId1) {
      return String(left)
    }
    return ""
  }

  private func backupUser(_ userId: String) -> String {
    if capacity[userId] == nil {
      return ""
    }
    var snap: [(String, Int64)] = []
    for name in fileOrder {
      if let item = files[name], item.owner == userId {
        snap.append((name, item.size))
      }
    }
    let count = String(snap.count)
    backups[userId] = snap
    return count
  }

  private func restoreUser(_ userId: String) -> String {
    if capacity[userId] == nil {
      return ""
    }
    let owned = files.values.filter { $0.owner == userId }.map(\.name)
    for name in owned {
      files[name] = nil
      fileOrder.removeAll { $0 == name }
    }
    guard let snap = backups[userId] else {
      return "0"
    }
    var restored: Int64 = 0
    for item in snap {
      if files[item.0] != nil {
        continue
      }
      if let left = remaining(userId), item.1 > left {
        continue
      }
      files[item.0] = StoredFile(name: item.0, size: item.1, owner: userId)
      fileOrder.append(item.0)
      restored += 1
    }
    return String(restored)
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "addFile":
      text = try addFile(argStr(args, 0), argI64(args, 1))
    case "getFileSize":
      text = try getFileSize(argStr(args, 0))
    case "deleteFile":
      text = try deleteFile(argStr(args, 0))
    case "getNLargest":
      text = try getNLargest(argStr(args, 0), argI64(args, 1))
    case "addUser":
      text = try addUser(argStr(args, 0), argI64(args, 1))
    case "addFileBy":
      text = try addFileBy(argStr(args, 0), argStr(args, 1), argI64(args, 2))
    case "mergeUser":
      text = try mergeUser(argStr(args, 0), argStr(args, 1))
    case "backupUser":
      text = try backupUser(argStr(args, 0))
    case "restoreUser":
      text = try restoreUser(argStr(args, 0))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
