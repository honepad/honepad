class Gpu {
  constructor(gpuId, mem) {
    this.gpuId = gpuId;
    this.mem = mem;
    this.jobId = null;
  }
}

class Job {
  constructor(jobId, mem, seq) {
    this.jobId = jobId;
    this.mem = mem;
    this.seq = seq;
    this.priority = 0;
    this.state = "queued";
    this.gpuId = null;
  }
}

class Simulation {
  constructor() {
    this.gpus = {};
    this.gpuOrder = [];
    this.jobs = {};
    this.nextSeq = 0;
  }

  addGpu(gpuId, mem) {
    if (mem <= 0) return "invalid_request";
    if (Object.prototype.hasOwnProperty.call(this.gpus, gpuId)) return "false";
    this.gpus[gpuId] = new Gpu(gpuId, mem);
    this.gpuOrder.push(gpuId);
    return "true";
  }

  submitJob(jobId, mem) {
    if (mem <= 0) return "invalid_request";
    if (Object.prototype.hasOwnProperty.call(this.jobs, jobId)) return "false";
    this.jobs[jobId] = new Job(jobId, mem, this.nextSeq);
    this.nextSeq += 1;
    return "true";
  }

  status(jobId) {
    const job = this.jobs[jobId];
    return job ? job.state : "";
  }

  _place(job, gpu) {
    job.state = "running";
    job.gpuId = gpu.gpuId;
    gpu.jobId = job.jobId;
  }

  assign() {
    const queued = Object.values(this.jobs).filter((job) => job.state === "queued");
    queued.sort((a, b) => b.priority - a.priority || a.seq - b.seq);
    for (const job of queued) {
      for (const gpuId of this.gpuOrder) {
        const gpu = this.gpus[gpuId];
        if (gpu.jobId === null && gpu.mem >= job.mem) {
          this._place(job, gpu);
          return job.jobId;
        }
      }
    }
    return "";
  }

  complete(jobId) {
    const job = this.jobs[jobId];
    if (!job || job.state !== "running" || job.gpuId === null) return "invalid_request";
    this.gpus[job.gpuId].jobId = null;
    job.gpuId = null;
    job.state = "done";
    return "true";
  }

  cancel(jobId) {
    const job = this.jobs[jobId];
    if (!job || job.state === "done") return "invalid_request";
    if (job.state === "running" && job.gpuId !== null) {
      this.gpus[job.gpuId].jobId = null;
    }
    delete this.jobs[jobId];
    if (job.state === "running") this.assign();
    return "true";
  }

  setPriority(jobId, priority) {
    const job = this.jobs[jobId];
    if (!job || job.state !== "queued") return "invalid_request";
    job.priority = priority;
    return "true";
  }
}

module.exports = { Simulation };
