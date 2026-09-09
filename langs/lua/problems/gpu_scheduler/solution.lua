Gpu = {}
Gpu.__index = Gpu

function Gpu.new(gpu_id, mem)
  local self = setmetatable({}, Gpu)
  self.gpu_id = gpu_id
  self.mem = mem
  self.job_id = nil
  return self
end

Job = {}
Job.__index = Job

function Job.new(job_id, mem, seq)
  local self = setmetatable({}, Job)
  self.job_id = job_id
  self.mem = mem
  self.seq = seq
  self.priority = 0
  self.state = "queued"
  self.gpu_id = nil
  return self
end

Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.gpus = {}
  self.gpu_order = {}
  self.jobs = {}
  self.next_seq = 0
  return self
end

function Simulation:add_gpu(gpu_id, mem)
  if mem <= 0 then
    return "invalid_request"
  end
  if self.gpus[gpu_id] then
    return "false"
  end
  self.gpus[gpu_id] = Gpu.new(gpu_id, mem)
  self.gpu_order[#self.gpu_order + 1] = gpu_id
  return "true"
end

function Simulation:submit_job(job_id, mem)
  if mem <= 0 then
    return "invalid_request"
  end
  if self.jobs[job_id] then
    return "false"
  end
  self.jobs[job_id] = Job.new(job_id, mem, self.next_seq)
  self.next_seq = self.next_seq + 1
  return "true"
end

function Simulation:status(job_id)
  local job = self.jobs[job_id]
  if not job then
    return ""
  end
  return job.state
end

function Simulation:_place(job, gpu)
  job.state = "running"
  job.gpu_id = gpu.gpu_id
  gpu.job_id = job.job_id
end

function Simulation:assign()
  local queued = {}
  for _, job in pairs(self.jobs) do
    if job.state == "queued" then
      queued[#queued + 1] = job
    end
  end
  table.sort(queued, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    end
    return a.seq < b.seq
  end)
  for _, job in ipairs(queued) do
    for _, gpu_id in ipairs(self.gpu_order) do
      local gpu = self.gpus[gpu_id]
      if gpu.job_id == nil and gpu.mem >= job.mem then
        self:_place(job, gpu)
        return job.job_id
      end
    end
  end
  return ""
end

function Simulation:complete(job_id)
  local job = self.jobs[job_id]
  if not job or job.state ~= "running" or job.gpu_id == nil then
    return "invalid_request"
  end
  self.gpus[job.gpu_id].job_id = nil
  job.gpu_id = nil
  job.state = "done"
  return "true"
end

function Simulation:cancel(job_id)
  local job = self.jobs[job_id]
  if not job or job.state == "done" then
    return "invalid_request"
  end
  if job.state == "running" and job.gpu_id ~= nil then
    self.gpus[job.gpu_id].job_id = nil
  end
  self.jobs[job_id] = nil
  if job.state == "running" then
    self:assign()
  end
  return "true"
end

function Simulation:set_priority(job_id, priority)
  local job = self.jobs[job_id]
  if not job or job.state ~= "queued" then
    return "invalid_request"
  end
  job.priority = priority
  return "true"
end
