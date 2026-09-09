import Foundation

struct Item {
  var sku: String
  var name: String
  var qty: Int64 = 0
  var reserved: Int64 = 0
}

final class Simulation: Harness {
  private var items: [String: Item] = [:]

  private func createItem(_ sku: String, _ name: String) -> String {
    if items[sku] != nil {
      return "false"
    }
    items[sku] = Item(sku: sku, name: name)
    return "true"
  }

  private func stock(_ sku: String, _ delta: Int64) -> String {
    guard var item = items[sku] else {
      return ""
    }
    let nxt = item.qty + delta
    if nxt < item.reserved {
      return "invalid_request"
    }
    item.qty = nxt
    items[sku] = item
    return String(item.qty)
  }

  private func getQty(_ sku: String) -> String {
    guard let item = items[sku] else {
      return ""
    }
    return String(item.qty)
  }

  private func listLow(_ threshold: Int64) -> String {
    var matched = items.values.filter { $0.qty <= threshold }
    matched.sort { left, right in
      if left.qty != right.qty {
        return left.qty < right.qty
      }
      return left.sku < right.sku
    }
    return matched.map { "\($0.sku)(\($0.qty))" }.joined(separator: ", ")
  }

  private func reserve(_ sku: String, _ n: Int64) -> String {
    guard var item = items[sku] else {
      return "invalid_request"
    }
    if n <= 0 || item.reserved + n > item.qty {
      return "invalid_request"
    }
    item.reserved += n
    items[sku] = item
    return "true"
  }

  private func release(_ sku: String, _ n: Int64) -> String {
    guard var item = items[sku] else {
      return "invalid_request"
    }
    if n <= 0 || n > item.reserved {
      return "invalid_request"
    }
    item.reserved -= n
    items[sku] = item
    return "true"
  }

  private func ship(_ sku: String, _ n: Int64) -> String {
    guard var item = items[sku] else {
      return "invalid_request"
    }
    if n <= 0 || n > item.reserved {
      return "invalid_request"
    }
    item.reserved -= n
    item.qty -= n
    items[sku] = item
    return "true"
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "createItem":
      text = try createItem(argStr(args, 0), argStr(args, 1))
    case "stock":
      text = try stock(argStr(args, 0), argI64(args, 1))
    case "getQty":
      text = try getQty(argStr(args, 0))
    case "listLow":
      text = try listLow(argI64(args, 0))
    case "reserve":
      text = try reserve(argStr(args, 0), argI64(args, 1))
    case "release":
      text = try release(argStr(args, 0), argI64(args, 1))
    case "ship":
      text = try ship(argStr(args, 0), argI64(args, 1))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
