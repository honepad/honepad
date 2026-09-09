KeyState = {}
KeyState.__index = KeyState

function KeyState.new()
  local self = setmetatable({}, KeyState)
  self.limit = 3
  self.window = 10
  self.window_id = nil
  self.used = 0
  return self
end

Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.keys = {}
  return self
end

function Simulation:_state(key)
  local item = self.keys[key]
  if not item then
    item = KeyState.new()
    self.keys[key] = item
  end
  return item
end

function Simulation:_used_at(item, timestamp, persist)
  local window_id = math.floor(timestamp / item.window)
  if item.window_id == nil or window_id ~= item.window_id then
    if persist then
      item.window_id = window_id
      item.used = 0
    end
    return 0
  end
  return item.used
end

function Simulation:allow(key, timestamp)
  return self:allow_weighted(key, 1, timestamp)
end

function Simulation:configure(key, limit, window)
  if limit <= 0 or window <= 0 then
    return "invalid_request"
  end
  local item = self:_state(key)
  item.limit = limit
  item.window = window
  item.window_id = nil
  item.used = 0
  return "true"
end

function Simulation:remaining(key, timestamp)
  local item = self:_state(key)
  local used = self:_used_at(item, timestamp, false)
  return tostring(item.limit - used)
end

function Simulation:allow_weighted(key, cost, timestamp)
  if cost <= 0 then
    return "invalid_request"
  end
  local item = self:_state(key)
  self:_used_at(item, timestamp, true)
  if item.used + cost > item.limit then
    return "false"
  end
  item.used = item.used + cost
  return "true"
end
