class Item {
  constructor(sku, name) {
    this.sku = sku;
    this.name = name;
    this.qty = 0;
    this.reserved = 0;
  }
}

class Simulation {
  constructor() {
    this.items = {};
  }

  createItem(sku, name) {
    if (Object.prototype.hasOwnProperty.call(this.items, sku)) return "false";
    this.items[sku] = new Item(sku, name);
    return "true";
  }

  stock(sku, delta) {
    const item = this.items[sku];
    if (!item) return "";
    const nxt = item.qty + delta;
    if (nxt < item.reserved) return "invalid_request";
    item.qty = nxt;
    return String(item.qty);
  }

  getQty(sku) {
    const item = this.items[sku];
    if (!item) return "";
    return String(item.qty);
  }

  listLow(threshold) {
    const matched = Object.values(this.items).filter((item) => item.qty <= threshold);
    matched.sort(
      (a, b) =>
        a.qty - b.qty ||
        (a.sku < b.sku ? -1 : a.sku > b.sku ? 1 : 0),
    );
    return matched.map((item) => `${item.sku}(${item.qty})`).join(", ");
  }

  reserve(sku, n) {
    const item = this.items[sku];
    if (!item || n <= 0 || item.reserved + n > item.qty) return "invalid_request";
    item.reserved += n;
    return "true";
  }

  release(sku, n) {
    const item = this.items[sku];
    if (!item || n <= 0 || n > item.reserved) return "invalid_request";
    item.reserved -= n;
    return "true";
  }

  ship(sku, n) {
    const item = this.items[sku];
    if (!item || n <= 0 || n > item.reserved) return "invalid_request";
    item.reserved -= n;
    item.qty -= n;
    return "true";
  }
}

module.exports = { Simulation };
