import std/[tables, algorithm]

type
  Gpu = ref object
    gpuId: string
    mem: int64
    jobId: string

  Job = ref object
    jobId: string
    mem: int64
    seq: int64
    priority: int64
    state: string
    gpuId: string

  Simulation = ref object
    gpus: Table[string, Gpu]
    gpuOrder: seq[string]
    jobs: Table[string, Job]
    nextSeq: int64

proc addGpu(self: Simulation; gpuId: string; mem: int64): string =
  if mem <= 0:
    return "invalid_request"
  if gpuId in self.gpus:
    return "false"
  self.gpus[gpuId] = Gpu(gpuId: gpuId, mem: mem, jobId: "")
  self.gpuOrder.add(gpuId)
  result = "true"

proc submitJob(self: Simulation; jobId: string; mem: int64): string =
  if mem <= 0:
    return "invalid_request"
  if jobId in self.jobs:
    return "false"
  self.jobs[jobId] = Job(jobId: jobId, mem: mem, seq: self.nextSeq, priority: 0, state: "queued", gpuId: "")
  self.nextSeq += 1
  result = "true"

proc status(self: Simulation; jobId: string): string =
  if jobId notin self.jobs:
    return ""
  result = self.jobs[jobId].state

proc place(job: Job; gpu: Gpu) =
  job.state = "running"
  job.gpuId = gpu.gpuId
  gpu.jobId = job.jobId

proc assign(self: Simulation): string =
  var queued: seq[Job] = @[]
  for job in self.jobs.values:
    if job.state == "queued":
      queued.add(job)
  queued.sort(
    proc (a, b: Job): int =
      result = cmp(b.priority, a.priority)
      if result == 0:
        result = cmp(a.seq, b.seq)
  )
  for job in queued:
    for gpuId in self.gpuOrder:
      let gpu = self.gpus[gpuId]
      if gpu.jobId.len == 0 and gpu.mem >= job.mem:
        place(job, gpu)
        return job.jobId
  result = ""

proc complete(self: Simulation; jobId: string): string =
  if jobId notin self.jobs:
    return "invalid_request"
  let job = self.jobs[jobId]
  if job.state != "running" or job.gpuId.len == 0:
    return "invalid_request"
  self.gpus[job.gpuId].jobId = ""
  job.gpuId = ""
  job.state = "done"
  result = "true"

proc cancel(self: Simulation; jobId: string): string =
  if jobId notin self.jobs:
    return "invalid_request"
  let job = self.jobs[jobId]
  if job.state == "done":
    return "invalid_request"
  let running = job.state == "running"
  if running and job.gpuId.len > 0:
    self.gpus[job.gpuId].jobId = ""
  self.jobs.del(jobId)
  if running:
    discard self.assign()
  result = "true"

proc setPriority(self: Simulation; jobId: string; priority: int64): string =
  if jobId notin self.jobs:
    return "invalid_request"
  let job = self.jobs[jobId]
  if job.state != "queued":
    return "invalid_request"
  job.priority = priority
  result = "true"
