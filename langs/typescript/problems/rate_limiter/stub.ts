class Simulation {
  constructor() {}
  allow(key, timestamp) { throw new Error('not implemented'); }
  configure(key, limit, window) { throw new Error('not implemented'); }
  remaining(key, timestamp) { throw new Error('not implemented'); }
  allowWeighted(key, cost, timestamp) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
