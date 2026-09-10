Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.subs = {}
  self.inbox_map = {}
  self.retained = {}
  return self
end

function Simulation:subscribe(topic, client)
  local clients = self.subs[topic]
  if not clients then
    clients = {}
    self.subs[topic] = clients
  end
  for _, existing in ipairs(clients) do
    if existing == client then
      return "false"
    end
  end
  clients[#clients + 1] = client
  if self.retained[topic] then
    local items = self.inbox_map[client]
    if not items then
      items = {}
      self.inbox_map[client] = items
    end
    items[#items + 1] = topic .. ":" .. self.retained[topic]
  end
  return "true"
end

function Simulation:unsubscribe(topic, client)
  local clients = self.subs[topic]
  if not clients then
    return "false"
  end
  local idx = nil
  for i, existing in ipairs(clients) do
    if existing == client then
      idx = i
      break
    end
  end
  if not idx then
    return "false"
  end
  table.remove(clients, idx)
  if #clients == 0 then
    self.subs[topic] = nil
  end
  return "true"
end

function Simulation:publish(topic, message)
  local clients = self.subs[topic] or {}
  local payload = topic .. ":" .. message
  for _, client in ipairs(clients) do
    local items = self.inbox_map[client]
    if not items then
      items = {}
      self.inbox_map[client] = items
    end
    items[#items + 1] = payload
  end
  return tostring(#clients)
end

function Simulation:inbox(client)
  local items = self.inbox_map[client] or {}
  return table.concat(items, ", ")
end

function Simulation:list_topics()
  local topics = {}
  for topic, _ in pairs(self.subs) do
    topics[#topics + 1] = topic
  end
  table.sort(topics)
  return table.concat(topics, ", ")
end

function Simulation:subscribers(topic)
  local clients = {}
  if self.subs[topic] then
    for i, client in ipairs(self.subs[topic]) do
      clients[i] = client
    end
  end
  table.sort(clients)
  return table.concat(clients, ", ")
end

function Simulation:peek(client)
  local items = self.inbox_map[client] or {}
  if #items == 0 then
    return ""
  end
  return items[1]
end

function Simulation:ack(client, n)
  if n <= 0 or not self.inbox_map[client] then
    return "invalid_request"
  end
  local items = self.inbox_map[client]
  if n > #items then
    return "invalid_request"
  end
  for _ = 1, n do
    table.remove(items, 1)
  end
  return tostring(#items)
end

function Simulation:retain(topic, message)
  self.retained[topic] = message
  return ""
end
