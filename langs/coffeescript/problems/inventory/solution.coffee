class Item
  constructor: (sku, name) ->
    @sku = sku
    @name = name
    @qty = 0
    @reserved = 0

class Simulation
  constructor: ->
    @items = {}

  createItem: (sku, name) ->
    return "false" if Object.prototype.hasOwnProperty.call(@items, sku)
    @items[sku] = new Item sku, name
    "true"

  stock: (sku, delta) ->
    item = @items[sku]
    return "" unless item
    nxt = item.qty + delta
    return "invalid_request" if nxt < item.reserved
    item.qty = nxt
    String item.qty

  getQty: (sku) ->
    item = @items[sku]
    return "" unless item
    String item.qty

  listLow: (threshold) ->
    matched = Object.values(@items).filter (item) ->
      item.qty <= threshold
    matched.sort (a, b) ->
      a.qty - b.qty or
        (if a.sku < b.sku then -1 else if a.sku > b.sku then 1 else 0)
    matched.map((item) ->
      "#{item.sku}(#{item.qty})"
    ).join ", "

  reserve: (sku, n) ->
    item = @items[sku]
    return "invalid_request" if not item or n <= 0 or item.reserved + n > item.qty
    item.reserved += n
    "true"

  release: (sku, n) ->
    item = @items[sku]
    return "invalid_request" if not item or n <= 0 or n > item.reserved
    item.reserved -= n
    "true"

  ship: (sku, n) ->
    item = @items[sku]
    return "invalid_request" if not item or n <= 0 or n > item.reserved
    item.reserved -= n
    item.qty -= n
    "true"

module.exports = { Simulation }
