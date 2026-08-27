Worker = {}
Worker.__index = Worker

function Worker.new(worker_id, position, compensation)
  local self = setmetatable({}, Worker)
  self.worker_id = worker_id
  self.position = position
  self.compensation = compensation
  self.in_office = false
  self.entered_at = nil
  self.finished = {}
  self.pending_promo = nil
  return self
end

function Worker:total_time()
  local total = 0
  for _, row in ipairs(self.finished) do
    total = total + (row[2] - row[1])
  end
  return total
end

function Worker:position_time(position)
  local total = 0
  for _, row in ipairs(self.finished) do
    if row[4] == position then
      total = total + (row[2] - row[1])
    end
  end
  return total
end

function Worker:apply_promo_on_enter(timestamp)
  if not self.pending_promo then
    return
  end
  local new_pos, new_comp, start_ts = self.pending_promo[1], self.pending_promo[2], self.pending_promo[3]
  if timestamp < start_ts then
    return
  end
  self.position = new_pos
  self.compensation = new_comp
  self.pending_promo = nil
end

Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.workers = {}
  return self
end

function Simulation:add_worker(worker_id, position, compensation)
  if self.workers[worker_id] then
    return "false"
  end
  self.workers[worker_id] = Worker.new(worker_id, position, compensation)
  return "true"
end

function Simulation:register(worker_id, timestamp)
  local worker = self.workers[worker_id]
  if not worker then
    return "invalid_request"
  end
  if worker.in_office then
    worker.finished[#worker.finished + 1] = {
      worker.entered_at,
      timestamp,
      worker.compensation,
      worker.position,
    }
    worker.in_office = false
    worker.entered_at = nil
    return "registered"
  end
  worker:apply_promo_on_enter(timestamp)
  worker.in_office = true
  worker.entered_at = timestamp
  return "registered"
end

function Simulation:get(worker_id)
  local worker = self.workers[worker_id]
  if not worker then
    return ""
  end
  return tostring(worker:total_time())
end

function Simulation:top_n_workers(n, position)
  local matched = {}
  for _, worker in pairs(self.workers) do
    if worker.position == position then
      matched[#matched + 1] = worker
    end
  end
  table.sort(matched, function(a, b)
    local ta = a:position_time(position)
    local tb = b:position_time(position)
    if ta ~= tb then
      return ta > tb
    end
    return a.worker_id < b.worker_id
  end)
  if #matched > n then
    for i = n + 1, #matched do
      matched[i] = nil
    end
  end
  local parts = {}
  for i, worker in ipairs(matched) do
    parts[i] = string.format("%s(%d)", worker.worker_id, worker:position_time(position))
  end
  return table.concat(parts, ", ")
end

function Simulation:promote(worker_id, new_position, new_compensation, start_timestamp)
  local worker = self.workers[worker_id]
  if not worker or worker.pending_promo then
    return "invalid_request"
  end
  worker.pending_promo = { new_position, new_compensation, start_timestamp }
  return "success"
end

function Simulation:calc_salary(worker_id, start_timestamp, end_timestamp)
  local worker = self.workers[worker_id]
  if not worker then
    return ""
  end
  local total = 0
  for _, row in ipairs(worker.finished) do
    local session_start, session_end, rate = row[1], row[2], row[3]
    local lo = session_start > start_timestamp and session_start or start_timestamp
    local hi = session_end < end_timestamp and session_end or end_timestamp
    if hi > lo then
      total = total + (hi - lo) * rate
    end
  end
  return tostring(total)
end
