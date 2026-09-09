Backend = {}
Backend.__index = Backend

function Backend.new(backend_id)
  local self = setmetatable({}, Backend)
  self.backend_id = backend_id
  self.health = true
  self.weight = 1
  self.inflight = 0
  return self
end

Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.backends = {}
  self.by_id = {}
  self.cursor = 0
  self.sticky_map = {}
  self.use_least = false
  return self
end

function Simulation:add_backend(backend_id)
  if self.by_id[backend_id] then
    return "false"
  end
  local item = Backend.new(backend_id)
  self.backends[#self.backends + 1] = item
  self.by_id[backend_id] = item
  return "true"
end

function Simulation:set_health(backend_id, flag)
  local item = self.by_id[backend_id]
  if not item or (flag ~= 0 and flag ~= 1) then
    return "invalid_request"
  end
  item.health = flag == 1
  self:_reset_cycle()
  return "true"
end

function Simulation:set_weight(backend_id, weight)
  local item = self.by_id[backend_id]
  if not item or weight <= 0 then
    return "invalid_request"
  end
  item.weight = weight
  self:_reset_cycle()
  return "true"
end

function Simulation:_reset_cycle()
  self.cursor = 0
  self.use_least = false
  for _, item in ipairs(self.backends) do
    item.inflight = 0
  end
end

function Simulation:_tickets(items)
  local tickets = {}
  for _, item in ipairs(items) do
    for _ = 1, item.weight do
      tickets[#tickets + 1] = item
    end
  end
  return tickets
end

function Simulation:_pick()
  local healthy = {}
  for _, item in ipairs(self.backends) do
    if item.health then
      healthy[#healthy + 1] = item
    end
  end
  if #healthy == 0 then
    return nil
  end
  local pool = healthy
  if self.use_least then
    local least = healthy[1].inflight
    for _, item in ipairs(healthy) do
      if item.inflight < least then
        least = item.inflight
      end
    end
    pool = {}
    for _, item in ipairs(healthy) do
      if item.inflight == least then
        pool[#pool + 1] = item
      end
    end
  end
  local tickets = self:_tickets(pool)
  if #tickets == 0 then
    return nil
  end
  local chosen = tickets[(self.cursor % #tickets) + 1]
  self.cursor = self.cursor + 1
  return chosen
end

function Simulation:_take()
  local item = self:_pick()
  if not item then
    return ""
  end
  item.inflight = item.inflight + 1
  return item.backend_id
end

function Simulation:route()
  return self:_take()
end

function Simulation:sticky(client_id)
  local bound = self.sticky_map[client_id]
  local item = bound and self.by_id[bound] or nil
  if item and item.health then
    item.inflight = item.inflight + 1
    return item.backend_id
  end
  local chosen = self:_take()
  if chosen ~= "" then
    self.sticky_map[client_id] = chosen
  end
  return chosen
end

function Simulation:done(backend_id)
  local item = self.by_id[backend_id]
  if not item or item.inflight <= 0 then
    return "invalid_request"
  end
  item.inflight = item.inflight - 1
  self.use_least = true
  return "true"
end
