import Foundation

struct FieldVal {
  var value: String
  var expiry: Int64?
}

final class InMemoryDatabase: Harness {
  private var database: [String: [String: FieldVal]] = [:]
  private var backupTimestamps: [Int64] = []
  private var backupStates: [[String: [String: FieldVal]]] = []

  private func setInternal(
    _ key: String,
    _ field: String,
    _ value: String,
    _ expiry: Int64?
  ) -> String {
    var fields = database[key] ?? [:]
    fields[field] = FieldVal(value: value, expiry: expiry)
    database[key] = fields
    return ""
  }

  private func isAlive(_ key: String, _ field: String, _ timestamp: Int64) -> Bool {
    guard let stored = database[key]?[field] else {
      return false
    }
    guard let expiry = stored.expiry else {
      return true
    }
    return timestamp < expiry
  }

  private func get(_ key: String, _ field: String) -> String {
    database[key]?[field]?.value ?? ""
  }

  private func del(_ key: String, _ field: String) -> String {
    guard var fields = database[key], fields[field] != nil else {
      return "false"
    }
    fields[field] = nil
    database[key] = fields
    return "true"
  }

  private func formatScan(_ names: [String], _ fields: [String: FieldVal]) -> String {
    names.enumerated().map { index, name in
      let prefix = index > 0 ? ", " : ""
      return "\(prefix)\(name)(\(fields[name]!.value))"
    }.joined()
  }

  private func scan(_ key: String) -> String {
    guard let fields = database[key] else {
      return ""
    }
    return formatScan(fields.keys.sorted(), fields)
  }

  private func scanByPrefix(_ key: String, _ prefix: String) -> String {
    guard let fields = database[key] else {
      return ""
    }
    let names = fields.keys.filter { $0.hasPrefix(prefix) }.sorted()
    return formatScan(names, fields)
  }

  private func deleteAt(_ key: String, _ field: String, _ timestamp: Int64) -> String {
    if !isAlive(key, field, timestamp) {
      return "false"
    }
    var fields = database[key] ?? [:]
    fields[field] = nil
    database[key] = fields
    return "true"
  }

  private func getAt(_ key: String, _ field: String, _ timestamp: Int64) -> String {
    if !isAlive(key, field, timestamp) {
      return ""
    }
    return database[key]![field]!.value
  }

  private func scanAt(_ key: String, _ timestamp: Int64) -> String {
    guard let fields = database[key] else {
      return ""
    }
    let names = fields.keys.filter { isAlive(key, $0, timestamp) }.sorted()
    return formatScan(names, fields)
  }

  private func scanByPrefixAt(_ key: String, _ prefix: String, _ timestamp: Int64) -> String {
    guard let fields = database[key] else {
      return ""
    }
    let names = fields.keys.filter { $0.hasPrefix(prefix) && isAlive(key, $0, timestamp) }.sorted()
    return formatScan(names, fields)
  }

  private func backup(_ timestamp: Int64) -> String {
    var state: [String: [String: FieldVal]] = [:]
    for (key, fields) in database {
      for (field, stored) in fields {
        if !isAlive(key, field, timestamp) {
          continue
        }
        var copy = stored
        if let expiry = stored.expiry {
          copy.expiry = expiry - timestamp
        }
        var dest = state[key] ?? [:]
        dest[field] = copy
        state[key] = dest
      }
    }
    backupTimestamps.append(timestamp)
    backupStates.append(state)
    return String(state.count)
  }

  private func restore(_ timestamp: Int64, _ timestampToRestore: Int64) -> String {
    var idx = -1
    for (index, backupTs) in backupTimestamps.enumerated() {
      if backupTs <= timestampToRestore {
        idx = index
      }
    }
    database.removeAll()
    if idx < 0 {
      return ""
    }
    let backup = backupStates[idx]
    for (key, fields) in backup {
      for (field, stored) in fields {
        var expiry: Int64?
        if let remaining = stored.expiry {
          expiry = timestamp + remaining
        }
        _ = setInternal(key, field, stored.value, expiry)
      }
    }
    return ""
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "set":
      text = try setInternal(argStr(args, 0), argStr(args, 1), argStr(args, 2), nil)
    case "get":
      text = try get(argStr(args, 0), argStr(args, 1))
    case "delete":
      text = try del(argStr(args, 0), argStr(args, 1))
    case "scan":
      text = try scan(argStr(args, 0))
    case "scanByPrefix":
      text = try scanByPrefix(argStr(args, 0), argStr(args, 1))
    case "setAt":
      text = try setInternal(argStr(args, 0), argStr(args, 1), argStr(args, 2), nil)
    case "setAtWithTtl":
      text = try setInternal(
        argStr(args, 0),
        argStr(args, 1),
        argStr(args, 2),
        argI64(args, 3) + argI64(args, 4)
      )
    case "deleteAt":
      text = try deleteAt(argStr(args, 0), argStr(args, 1), argI64(args, 2))
    case "getAt":
      text = try getAt(argStr(args, 0), argStr(args, 1), argI64(args, 2))
    case "scanAt":
      text = try scanAt(argStr(args, 0), argI64(args, 1))
    case "scanByPrefixAt":
      text = try scanByPrefixAt(argStr(args, 0), argStr(args, 1), argI64(args, 2))
    case "backup":
      text = try backup(argI64(args, 0))
    case "restore":
      text = try restore(argI64(args, 0), argI64(args, 1))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
