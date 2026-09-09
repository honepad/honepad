class Backend {
  constructor(backendId) {
    this.backendId = backendId;
    this.health = true;
    this.weight = 1;
    this.inflight = 0;
  }
}

class Simulation {
  constructor() {
    this.backends = [];
    this.byId = {};
    this.cursor = 0;
    this.stickyMap = {};
    this.useLeast = false;
  }

  addBackend(backendId) {
    if (Object.prototype.hasOwnProperty.call(this.byId, backendId)) return "false";
    const item = new Backend(backendId);
    this.backends.push(item);
    this.byId[backendId] = item;
    return "true";
  }

  setHealth(backendId, flag) {
    const item = Object.prototype.hasOwnProperty.call(this.byId, backendId)
      ? this.byId[backendId]
      : null;
    if (!item || (flag !== 0 && flag !== 1)) return "invalid_request";
    item.health = flag === 1;
    this._resetCycle();
    return "true";
  }

  setWeight(backendId, weight) {
    const item = Object.prototype.hasOwnProperty.call(this.byId, backendId)
      ? this.byId[backendId]
      : null;
    if (!item || weight <= 0) return "invalid_request";
    item.weight = weight;
    this._resetCycle();
    return "true";
  }

  _resetCycle() {
    this.cursor = 0;
    this.useLeast = false;
    for (const item of this.backends) item.inflight = 0;
  }

  _tickets(items) {
    const tickets = [];
    for (const item of items) {
      for (let i = 0; i < item.weight; i++) tickets.push(item);
    }
    return tickets;
  }

  _pick() {
    const healthy = this.backends.filter((item) => item.health);
    if (!healthy.length) return null;
    let pool = healthy;
    if (this.useLeast) {
      let least = healthy[0].inflight;
      for (const item of healthy) {
        if (item.inflight < least) least = item.inflight;
      }
      pool = healthy.filter((item) => item.inflight === least);
    }
    const tickets = this._tickets(pool);
    if (!tickets.length) return null;
    const chosen = tickets[this.cursor % tickets.length];
    this.cursor += 1;
    return chosen;
  }

  _take() {
    const item = this._pick();
    if (!item) return "";
    item.inflight += 1;
    return item.backendId;
  }

  route() {
    return this._take();
  }

  sticky(clientId) {
    const bound = Object.prototype.hasOwnProperty.call(this.stickyMap, clientId)
      ? this.stickyMap[clientId]
      : null;
    const item = bound && Object.prototype.hasOwnProperty.call(this.byId, bound)
      ? this.byId[bound]
      : null;
    if (item && item.health) {
      item.inflight += 1;
      return item.backendId;
    }
    const chosen = this._take();
    if (chosen) this.stickyMap[clientId] = chosen;
    return chosen;
  }

  done(backendId) {
    const item = Object.prototype.hasOwnProperty.call(this.byId, backendId)
      ? this.byId[backendId]
      : null;
    if (!item || item.inflight <= 0) return "invalid_request";
    item.inflight -= 1;
    this.useLeast = true;
    return "true";
  }
}

module.exports = { Simulation };
