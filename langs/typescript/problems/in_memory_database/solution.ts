class InMemoryDatabase {
  constructor() {
    this.database = {};
    this.backupTimestamps = [];
    this.backupStates = [];
  }

  _setInternal(key, field, value, expiry) {
    if (!this.database[key]) this.database[key] = {};
    this.database[key][field] = [value, expiry];
    return "";
  }

  _isAlive(key, field, timestamp) {
    if (!this.database[key] || !(field in this.database[key])) return false;
    const expiry = this.database[key][field][1];
    if (expiry === null || expiry === undefined) return true;
    return timestamp < expiry;
  }

  set(key, field, value) {
    return this._setInternal(key, field, value, null);
  }

  get(key, field) {
    if (!this.database[key] || !(field in this.database[key])) return "";
    return this.database[key][field][0];
  }

  delete(key, field) {
    if (!this.database[key] || !(field in this.database[key])) return "false";
    delete this.database[key][field];
    return "true";
  }

  scan(key) {
    if (!this.database[key]) return "";
    return Object.keys(this.database[key])
      .sort()
      .map((field) => `${field}(${this.database[key][field][0]})`)
      .join(", ");
  }

  scanByPrefix(key, prefix) {
    if (!this.database[key]) return "";
    return Object.keys(this.database[key])
      .filter((field) => field.startsWith(prefix))
      .sort()
      .map((field) => `${field}(${this.database[key][field][0]})`)
      .join(", ");
  }

  setAt(key, field, value, _timestamp) {
    return this._setInternal(key, field, value, null);
  }

  setAtWithTtl(key, field, value, timestamp, ttl) {
    return this._setInternal(key, field, value, timestamp + ttl);
  }

  deleteAt(key, field, timestamp) {
    if (!this._isAlive(key, field, timestamp)) return "false";
    delete this.database[key][field];
    return "true";
  }

  getAt(key, field, timestamp) {
    if (!this._isAlive(key, field, timestamp)) return "";
    return this.database[key][field][0];
  }

  scanAt(key, timestamp) {
    if (!this.database[key]) return "";
    return Object.keys(this.database[key])
      .filter((field) => this._isAlive(key, field, timestamp))
      .sort()
      .map((field) => `${field}(${this.database[key][field][0]})`)
      .join(", ");
  }

  scanByPrefixAt(key, prefix, timestamp) {
    if (!this.database[key]) return "";
    return Object.keys(this.database[key])
      .filter((field) => field.startsWith(prefix) && this._isAlive(key, field, timestamp))
      .sort()
      .map((field) => `${field}(${this.database[key][field][0]})`)
      .join(", ");
  }

  backup(timestamp) {
    const state = {};
    for (const key of Object.keys(this.database)) {
      for (const field of Object.keys(this.database[key])) {
        if (this._isAlive(key, field, timestamp)) {
          const [value, expiry] = this.database[key][field];
          const remaining = expiry === null || expiry === undefined ? null : expiry - timestamp;
          if (!state[key]) state[key] = {};
          state[key][field] = [value, remaining];
        }
      }
    }
    this.backupTimestamps.push(timestamp);
    this.backupStates.push(state);
    return String(Object.keys(state).length);
  }

  restore(timestamp, timestampToRestore) {
    let idx = -1;
    for (let i = 0; i < this.backupTimestamps.length; i++) {
      if (this.backupTimestamps[i] <= timestampToRestore) idx = i;
    }
    const backup = this.backupStates[idx];
    this.database = {};
    for (const key of Object.keys(backup)) {
      for (const field of Object.keys(backup[key])) {
        const [value, remaining] = backup[key][field];
        const expiry = remaining === null || remaining === undefined ? null : timestamp + remaining;
        this._setInternal(key, field, value, expiry);
      }
    }
    return "";
  }
}

module.exports = { InMemoryDatabase };
