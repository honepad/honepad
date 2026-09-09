import std/[tables, algorithm, strutils]

type
  Item = ref object
    sku: string
    name: string
    qty: int64
    reserved: int64

  Simulation = ref object
    items: Table[string, Item]

proc createItem(self: Simulation; sku, name: string): string =
  if sku in self.items:
    return "false"
  self.items[sku] = Item(sku: sku, name: name, qty: 0, reserved: 0)
  result = "true"

proc stock(self: Simulation; sku: string; delta: int64): string =
  if sku notin self.items:
    return ""
  let item = self.items[sku]
  let nxt = item.qty + delta
  if nxt < item.reserved:
    return "invalid_request"
  item.qty = nxt
  result = $item.qty

proc getQty(self: Simulation; sku: string): string =
  if sku notin self.items:
    return ""
  result = $self.items[sku].qty

proc listLow(self: Simulation; threshold: int64): string =
  var matched: seq[Item] = @[]
  for item in self.items.values:
    if item.qty <= threshold:
      matched.add(item)
  matched.sort(
    proc (a, b: Item): int =
      result = cmp(a.qty, b.qty)
      if result == 0:
        result = cmp(a.sku, b.sku)
  )
  var parts: seq[string] = @[]
  for item in matched:
    parts.add(item.sku & "(" & $item.qty & ")")
  result = parts.join(", ")

proc reserve(self: Simulation; sku: string; n: int64): string =
  if sku notin self.items or n <= 0 or self.items[sku].reserved + n > self.items[sku].qty:
    return "invalid_request"
  self.items[sku].reserved += n
  result = "true"

proc release(self: Simulation; sku: string; n: int64): string =
  if sku notin self.items or n <= 0 or n > self.items[sku].reserved:
    return "invalid_request"
  self.items[sku].reserved -= n
  result = "true"

proc ship(self: Simulation; sku: string; n: int64): string =
  if sku notin self.items or n <= 0 or n > self.items[sku].reserved:
    return "invalid_request"
  self.items[sku].reserved -= n
  self.items[sku].qty -= n
  result = "true"
