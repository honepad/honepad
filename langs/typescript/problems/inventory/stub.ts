class Simulation {
  constructor() {}
  createItem(sku, name) { throw new Error('not implemented'); }
  stock(sku, delta) { throw new Error('not implemented'); }
  getQty(sku) { throw new Error('not implemented'); }
  listLow(threshold) { throw new Error('not implemented'); }
  reserve(sku, n) { throw new Error('not implemented'); }
  release(sku, n) { throw new Error('not implemented'); }
  ship(sku, n) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
