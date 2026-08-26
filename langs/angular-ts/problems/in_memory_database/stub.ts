class InMemoryDatabase {
  constructor() {}
  set(key, field, value) { throw new Error('not implemented'); }
  get(key, field) { throw new Error('not implemented'); }
  delete(key, field) { throw new Error('not implemented'); }
  scan(key) { throw new Error('not implemented'); }
  scanByPrefix(key, prefix) { throw new Error('not implemented'); }
  setAt(key, field, value, timestamp) { throw new Error('not implemented'); }
  setAtWithTtl(key, field, value, timestamp, ttl) { throw new Error('not implemented'); }
  deleteAt(key, field, timestamp) { throw new Error('not implemented'); }
  getAt(key, field, timestamp) { throw new Error('not implemented'); }
  scanAt(key, timestamp) { throw new Error('not implemented'); }
  scanByPrefixAt(key, prefix, timestamp) { throw new Error('not implemented'); }
  backup(timestamp) { throw new Error('not implemented'); }
  restore(timestamp, timestamp_to_restore) { throw new Error('not implemented'); }
}
module.exports = { InMemoryDatabase };
