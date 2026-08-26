class Simulation {
  constructor() {}
  addWorker(worker_id, position, compensation) { throw new Error('not implemented'); }
  register(worker_id, timestamp) { throw new Error('not implemented'); }
  get(worker_id) { throw new Error('not implemented'); }
  topNWorkers(n, position) { throw new Error('not implemented'); }
  promote(worker_id, new_position, new_compensation, start_timestamp) { throw new Error('not implemented'); }
  calcSalary(worker_id, start_timestamp, end_timestamp) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
