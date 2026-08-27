Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.files = {}
  self.order = {}
  self.capacity = { admin = false }
  self.capacity_set = { admin = true }
  self.unlimited = { admin = true }
  self.backups = {}
  return self
end

function Simulation:used(user_id)
  local total = 0
  for _, name in ipairs(self.order) do
    local item = self.files[name]
    if item.owner == user_id then
      total = total + item.size
    end
  end
  return total
end

function Simulation:remaining(user_id)
  if not self.capacity_set[user_id] then
    return nil
  end
  if self.unlimited[user_id] then
    return nil
  end
  return self.capacity[user_id] - self:used(user_id)
end

function Simulation:_add(name, size, owner)
  self.files[name] = { name = name, size = size, owner = owner }
  self.order[#self.order + 1] = name
end

function Simulation:_delete_name(name)
  self.files[name] = nil
  local next_order = {}
  for _, existing in ipairs(self.order) do
    if existing ~= name then
      next_order[#next_order + 1] = existing
    end
  end
  self.order = next_order
end

function Simulation:add_file(name, size)
  if self.files[name] then
    return "false"
  end
  self:_add(name, size, "admin")
  return "true"
end

function Simulation:get_file_size(name)
  local item = self.files[name]
  if not item then
    return ""
  end
  return tostring(item.size)
end

function Simulation:delete_file(name)
  local item = self.files[name]
  if not item then
    return ""
  end
  local size = item.size
  self:_delete_name(name)
  return tostring(size)
end

function Simulation:copy_file(source, dest)
  local src = self.files[source]
  if not src then
    return ""
  end
  if source == dest then
    return tostring(src.size)
  end
  local dest_item = self.files[dest]
  local owner = dest_item and dest_item.owner or src.owner
  local extra = dest_item and (src.size - dest_item.size) or src.size
  local left = self:remaining(owner)
  if left ~= nil and extra > left then
    return ""
  end
  if not dest_item then
    self:_add(dest, src.size, owner)
  else
    dest_item.size = src.size
  end
  return tostring(src.size)
end

function Simulation:get_n_largest(prefix, n)
  local matched = {}
  for _, name in ipairs(self.order) do
    local item = self.files[name]
    if item.name:sub(1, #prefix) == prefix then
      matched[#matched + 1] = item
    end
  end
  table.sort(matched, function(a, b)
    if a.size ~= b.size then
      return a.size > b.size
    end
    return a.name < b.name
  end)
  if #matched > n then
    for i = n + 1, #matched do
      matched[i] = nil
    end
  end
  local parts = {}
  for i, item in ipairs(matched) do
    parts[i] = string.format("%s(%d)", item.name, item.size)
  end
  return table.concat(parts, ", ")
end

function Simulation:add_user(user_id, capacity)
  if self.capacity_set[user_id] then
    return "false"
  end
  self.capacity[user_id] = capacity
  self.capacity_set[user_id] = true
  self.unlimited[user_id] = false
  return "true"
end

function Simulation:add_file_by(user_id, name, size)
  if not self.capacity_set[user_id] or self.files[name] then
    return ""
  end
  local left = self:remaining(user_id)
  if left ~= nil and size > left then
    return ""
  end
  self:_add(name, size, user_id)
  left = self:remaining(user_id)
  if left == nil then
    return ""
  end
  return tostring(left)
end

function Simulation:merge_user(user_id1, user_id2)
  if user_id1 == user_id2 then
    return ""
  end
  if not self.capacity_set[user_id1] or not self.capacity_set[user_id2] then
    return ""
  end
  if self.unlimited[user_id1] or self.unlimited[user_id2] then
    return ""
  end
  self.capacity[user_id1] = self.capacity[user_id1] + self.capacity[user_id2]
  for _, name in ipairs(self.order) do
    local item = self.files[name]
    if item.owner == user_id2 then
      item.owner = user_id1
    end
  end
  self.capacity[user_id2] = nil
  self.capacity_set[user_id2] = nil
  self.unlimited[user_id2] = nil
  self.backups[user_id2] = nil
  local left = self:remaining(user_id1)
  if left == nil then
    return ""
  end
  return tostring(left)
end

function Simulation:backup_user(user_id)
  if not self.capacity_set[user_id] then
    return ""
  end
  local snap = {}
  for _, name in ipairs(self.order) do
    local item = self.files[name]
    if item.owner == user_id then
      snap[#snap + 1] = { name, item.size }
    end
  end
  self.backups[user_id] = snap
  return tostring(#snap)
end

function Simulation:restore_user(user_id)
  if not self.capacity_set[user_id] then
    return ""
  end
  local keep = {}
  for _, name in ipairs(self.order) do
    local item = self.files[name]
    if item.owner == user_id then
      self.files[name] = nil
    else
      keep[#keep + 1] = name
    end
  end
  self.order = keep
  local snapshot = self.backups[user_id]
  if not snapshot then
    return "0"
  end
  local restored = 0
  for _, row in ipairs(snapshot) do
    local name, size = row[1], row[2]
    if not self.files[name] then
      local left = self:remaining(user_id)
      if left == nil or size <= left then
        self:_add(name, size, user_id)
        restored = restored + 1
      end
    end
  end
  return tostring(restored)
end
