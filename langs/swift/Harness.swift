import Foundation

protocol Harness {
  func call(_ method: String, _ args: [Any]) throws -> Any
}

enum HarnessError: Error, CustomStringConvertible {
  case missingArg(Int)
  case badArg(Int, String)
  case missingMethod(String)

  var description: String {
    switch self {
    case let .missingArg(index):
      return "missing arg \(index)"
    case let .badArg(index, message):
      return "arg \(index): \(message)"
    case let .missingMethod(method):
      return "missing method \(method)"
    }
  }
}

func isJSONBool(_ value: Any) -> Bool {
  #if canImport(CoreFoundation) && !os(Linux)
    if let number = value as? NSNumber {
      return CFGetTypeID(number) == CFBooleanGetTypeID()
    }
  #endif
  return type(of: value) == Bool.self
}

func asInt64(_ value: Any) -> Int64? {
  if isJSONBool(value) {
    return nil
  }
  if let number = value as? NSNumber {
    let whole = number.int64Value
    if number.doubleValue == Double(whole) {
      return whole
    }
    return nil
  }
  if let number = value as? Int64 {
    return number
  }
  if let number = value as? Int {
    return Int64(number)
  }
  if let number = value as? Int32 {
    return Int64(number)
  }
  if let number = value as? UInt {
    return Int64(number)
  }
  if let number = value as? Double {
    let whole = Int64(number)
    if number.isFinite, number == Double(whole) {
      return whole
    }
  }
  return nil
}

func argI64(_ args: [Any], _ index: Int) throws -> Int64 {
  guard index < args.count else {
    throw HarnessError.missingArg(index)
  }
  if let number = asInt64(args[index]) {
    return number
  }
  throw HarnessError.badArg(index, "not i64")
}

func argStr(_ args: [Any], _ index: Int) throws -> String {
  guard index < args.count else {
    throw HarnessError.missingArg(index)
  }
  if let text = args[index] as? String {
    return text
  }
  throw HarnessError.badArg(index, "not string")
}

func optI64(_ value: Int64?) -> Any {
  if let value {
    return value
  }
  return NSNull()
}

func optStr(_ value: String?) -> Any {
  if let value {
    return value
  }
  return NSNull()
}
