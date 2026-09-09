class Gpu
  constructor: (@gpuId, @mem) ->
    @jobId = null

class Job
  constructor: (@jobId, @mem, @seq) ->
    @priority = 0
    @state = "queued"
    @gpuId = null

class Simulation
  constructor: ->
    @gpus = {}
    @gpuOrder = []
    @jobs = {}
    @nextSeq = 0

  addGpu: (gpuId, mem) ->
    return "invalid_request" if mem <= 0
    return "false" if Object.prototype.hasOwnProperty.call(@gpus, gpuId)
    @gpus[gpuId] = new Gpu gpuId, mem
    @gpuOrder.push gpuId
    "true"

  submitJob: (jobId, mem) ->
    return "invalid_request" if mem <= 0
    return "false" if Object.prototype.hasOwnProperty.call(@jobs, jobId)
    @jobs[jobId] = new Job jobId, mem, @nextSeq
    @nextSeq += 1
    "true"

  status: (jobId) ->
    job = @jobs[jobId]
    if job then job.state else ""

  _place: (job, gpu) ->
    job.state = "running"
    job.gpuId = gpu.gpuId
    gpu.jobId = job.jobId

  assign: ->
    queued = (job for _, job of @jobs when job.state is "queued")
    queued.sort (a, b) -> b.priority - a.priority or a.seq - b.seq
    for job in queued
      for gpuId in @gpuOrder
        gpu = @gpus[gpuId]
        if gpu.jobId is null and gpu.mem >= job.mem
          @_place job, gpu
          return job.jobId
    ""

  complete: (jobId) ->
    job = @jobs[jobId]
    return "invalid_request" if not job or job.state isnt "running" or job.gpuId is null
    @gpus[job.gpuId].jobId = null
    job.gpuId = null
    job.state = "done"
    "true"

  cancel: (jobId) ->
    job = @jobs[jobId]
    return "invalid_request" if not job or job.state is "done"
    if job.state is "running" and job.gpuId isnt null
      @gpus[job.gpuId].jobId = null
    delete @jobs[jobId]
    @assign() if job.state is "running"
    "true"

  setPriority: (jobId, priority) ->
    job = @jobs[jobId]
    return "invalid_request" if not job or job.state isnt "queued"
    job.priority = priority
    "true"

module.exports = { Simulation }
