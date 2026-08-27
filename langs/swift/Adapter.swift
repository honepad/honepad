import Foundation

func toCamel(_ snake: String) -> String {
  if !snake.contains("_") {
    return snake
  }
  let parts = snake.split(separator: "_", omittingEmptySubsequences: false)
  var out = ""
  var first = true
  for part in parts {
    if first {
      out += part
      first = false
      continue
    }
    if part.isEmpty {
      continue
    }
    out += part.prefix(1).uppercased()
    out += part.dropFirst()
  }
  return out
}

func jsonReady(_ value: Any) -> Any {
  if value is NSNull {
    return NSNull()
  }
  if isJSONBool(value) {
    return (value as? Bool) ?? false
  }
  if let number = asInt64(value) {
    return NSNumber(value: number)
  }
  if let text = value as? String {
    return text
  }
  if let items = value as? [Any] {
    return items.map { jsonReady($0) }
  }
  if let object = value as? [String: Any] {
    var ready: [String: Any] = [:]
    for (key, item) in object {
      ready[key] = jsonReady(item)
    }
    return ready
  }
  return value
}

func jsonEqual(_ left: Any, _ right: Any) -> Bool {
  if left is NSNull, right is NSNull {
    return true
  }
  if isJSONBool(left), isJSONBool(right) {
    return ((left as? Bool) ?? false) == ((right as? Bool) ?? false)
  }
  if let leftText = left as? String, let rightText = right as? String {
    return leftText == rightText
  }
  if let leftNumber = asInt64(left), let rightNumber = asInt64(right) {
    return leftNumber == rightNumber
  }
  if let leftItems = left as? [Any], let rightItems = right as? [Any] {
    return leftItems.count == rightItems.count
      && zip(leftItems, rightItems).allSatisfy { jsonEqual($0, $1) }
  }
  if let leftObject = left as? [String: Any], let rightObject = right as? [String: Any] {
    if leftObject.count != rightObject.count {
      return false
    }
    for (key, leftItem) in leftObject {
      guard let rightItem = rightObject[key], jsonEqual(leftItem, rightItem) else {
        return false
      }
    }
    return true
  }
  return false
}

func failRow(
  _ caseId: String,
  _ index: Int,
  _ method: String,
  _ expected: Any,
  _ actual: Any
) -> [String: Any] {
  [
    "case": caseId,
    "index": index,
    "method": method,
    "expected": jsonReady(expected),
    "actual": jsonReady(actual),
  ]
}

func runAdapter() -> Int32 {
  let argv = CommandLine.arguments
  if argv.count < 2 {
    fputs("usage: adapter cases.json\n", stderr)
    return 2
  }
  let parsed: Any
  do {
    let data = try Data(contentsOf: URL(fileURLWithPath: argv[1]))
    parsed = try JSONSerialization.jsonObject(with: data, options: [])
  } catch {
    fputs("\(error)\n", stderr)
    return 2
  }
  guard let cases = parsed as? [Any] else {
    fputs("cases.json must be a JSON list\n", stderr)
    return 2
  }

  var failed: [[String: Any]] = []
  var passed = 0
  for rowAny in cases {
    guard let row = rowAny as? [String: Any] else {
      continue
    }
    let obj = newTarget()
    let caseId = row["id"] as? String ?? ""
    let calls = row["calls"] as? [Any] ?? []
    var ok = true
    for (index, callAny) in calls.enumerated() {
      guard let call = callAny as? [String: Any] else {
        continue
      }
      let methodSnake = call["m"] as? String ?? ""
      let method = toCamel(methodSnake)
      let args = call["a"] as? [Any] ?? []
      let expected = call["e"] ?? NSNull()
      let actual: Any
      do {
        actual = try obj.call(method, args)
      } catch {
        failed.append(failRow(caseId, index, methodSnake, expected, "exc:\(error)"))
        ok = false
        break
      }
      if !jsonEqual(actual, expected) {
        failed.append(failRow(caseId, index, methodSnake, expected, actual))
        ok = false
        break
      }
    }
    if ok {
      passed += 1
    }
  }

  let report: [String: Any] = [
    "passed": passed,
    "failed": failed,
  ]
  do {
    let data = try JSONSerialization.data(withJSONObject: jsonReady(report), options: [])
    if let text = String(data: data, encoding: .utf8) {
      print(text)
    }
  } catch {
    fputs("\(error)\n", stderr)
    return 2
  }
  return failed.isEmpty ? 0 : 1
}

@main
enum Runner {
  static func main() {
    exit(runAdapter())
  }
}
