class Simulation {
  constructor() {}
  addFile(name, size) { throw new Error('not implemented'); }
  getFileSize(name) { throw new Error('not implemented'); }
  deleteFile(name) { throw new Error('not implemented'); }
  getNLargest(prefix, n) { throw new Error('not implemented'); }
  addUser(user_id, capacity) { throw new Error('not implemented'); }
  addFileBy(user_id, name, size) { throw new Error('not implemented'); }
  mergeUser(user_id1, user_id2) { throw new Error('not implemented'); }
  backupUser(user_id) { throw new Error('not implemented'); }
  restoreUser(user_id) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
