class Simulation {
  constructor() {}
  addGpu(gpuId, mem) { throw new Error('not implemented'); }
  submitJob(jobId, mem) { throw new Error('not implemented'); }
  status(jobId) { throw new Error('not implemented'); }
  assign() { throw new Error('not implemented'); }
  complete(jobId) { throw new Error('not implemented'); }
  cancel(jobId) { throw new Error('not implemented'); }
  setPriority(jobId, priority) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
