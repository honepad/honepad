class Simulation {
  constructor() {
    this.files = {};
    this.capacity = { admin: null };
    this.backups = {};
  }

  _used(userId) {
    return Object.values(this.files)
      .filter((item) => item.owner === userId)
      .reduce((sum, item) => sum + item.size, 0);
  }

  _remaining(userId) {
    const cap = this.capacity[userId];
    if (cap === null || cap === undefined) return null;
    return cap - this._used(userId);
  }

  addFile(name, size) {
    if (this.files[name]) return "false";
    this.files[name] = { name, size, owner: "admin" };
    return "true";
  }

  getFileSize(name) {
    return this.files[name] ? String(this.files[name].size) : "";
  }

  deleteFile(name) {
    if (!this.files[name]) return "";
    const size = this.files[name].size;
    delete this.files[name];
    return String(size);
  }

  copyFile(source, dest) {
    const src = this.files[source];
    if (!src) return "";
    if (source === dest) return String(src.size);
    const destItem = this.files[dest];
    const owner = destItem ? destItem.owner : src.owner;
    const extra = destItem ? src.size - destItem.size : src.size;
    const remaining = this._remaining(owner);
    if (remaining !== null && extra > remaining) return "";
    if (!destItem) {
      this.files[dest] = { name: dest, size: src.size, owner };
    } else {
      destItem.size = src.size;
    }
    return String(src.size);
  }

  getNLargest(prefix, n) {
    const matched = Object.values(this.files).filter((item) =>
      item.name.startsWith(prefix),
    );
    matched.sort((a, b) => b.size - a.size || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
    return matched
      .slice(0, n)
      .map((item) => `${item.name}(${item.size})`)
      .join(", ");
  }

  addUser(userId, capacity) {
    if (Object.prototype.hasOwnProperty.call(this.capacity, userId)) return "false";
    this.capacity[userId] = capacity;
    return "true";
  }

  addFileBy(userId, name, size) {
    if (!Object.prototype.hasOwnProperty.call(this.capacity, userId) || this.files[name]) {
      return "";
    }
    const remaining = this._remaining(userId);
    if (remaining !== null && size > remaining) return "";
    this.files[name] = { name, size, owner: userId };
    const left = this._remaining(userId);
    return left === null ? "" : String(left);
  }

  mergeUser(userId1, userId2) {
    if (userId1 === userId2) return "";
    if (
      !Object.prototype.hasOwnProperty.call(this.capacity, userId1) ||
      !Object.prototype.hasOwnProperty.call(this.capacity, userId2)
    ) {
      return "";
    }
    if (this.capacity[userId1] === null || this.capacity[userId2] === null) return "";
    this.capacity[userId1] += this.capacity[userId2];
    for (const item of Object.values(this.files)) {
      if (item.owner === userId2) item.owner = userId1;
    }
    delete this.capacity[userId2];
    delete this.backups[userId2];
    return String(this._remaining(userId1));
  }

  backupUser(userId) {
    if (!Object.prototype.hasOwnProperty.call(this.capacity, userId)) return "";
    const snap = {};
    for (const item of Object.values(this.files)) {
      if (item.owner === userId) snap[item.name] = item.size;
    }
    this.backups[userId] = snap;
    return String(Object.keys(snap).length);
  }

  restoreUser(userId) {
    if (!Object.prototype.hasOwnProperty.call(this.capacity, userId)) return "";
    for (const name of Object.keys(this.files)) {
      if (this.files[name].owner === userId) delete this.files[name];
    }
    const snap = this.backups[userId];
    if (!snap) return "0";
    let restored = 0;
    for (const [name, size] of Object.entries(snap)) {
      if (this.files[name]) continue;
      const remaining = this._remaining(userId);
      if (remaining !== null && size > remaining) continue;
      this.files[name] = { name, size, owner: userId };
      restored += 1;
    }
    return String(restored);
  }
}

module.exports = { Simulation };
