class KeyState {
  constructor() {
    this.limit = 3;
    this.window = 10;
    this.windowId = null;
    this.used = 0;
  }
}

class Simulation {
  constructor() {
    this.keys = {};
  }

  _state(key) {
    let item = this.keys[key];
    if (!item) {
      item = new KeyState();
      this.keys[key] = item;
    }
    return item;
  }

  _usedAt(item, timestamp, persist) {
    const windowId = Math.floor(timestamp / item.window);
    if (item.windowId === null || windowId !== item.windowId) {
      if (persist) {
        item.windowId = windowId;
        item.used = 0;
      }
      return 0;
    }
    return item.used;
  }

  allow(key, timestamp) {
    return this.allowWeighted(key, 1, timestamp);
  }

  configure(key, limit, window) {
    if (limit <= 0 || window <= 0) return "invalid_request";
    const item = this._state(key);
    item.limit = limit;
    item.window = window;
    item.windowId = null;
    item.used = 0;
    return "true";
  }

  remaining(key, timestamp) {
    const item = this._state(key);
    const used = this._usedAt(item, timestamp, false);
    return String(item.limit - used);
  }

  allowWeighted(key, cost, timestamp) {
    if (cost <= 0) return "invalid_request";
    const item = this._state(key);
    this._usedAt(item, timestamp, true);
    if (item.used + cost > item.limit) return "false";
    item.used += cost;
    return "true";
  }
}

module.exports = { Simulation };
