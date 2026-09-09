class Simulation {
  constructor() {}
  addBackend(backendId) { throw new Error('not implemented'); }
  route() { throw new Error('not implemented'); }
  setHealth(backendId, flag) { throw new Error('not implemented'); }
  setWeight(backendId, weight) { throw new Error('not implemented'); }
  sticky(clientId) { throw new Error('not implemented'); }
  done(backendId) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
