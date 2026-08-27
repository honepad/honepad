InMemoryDatabase = {}
InMemoryDatabase.__index = InMemoryDatabase

function InMemoryDatabase.new()
  local self = setmetatable({}, InMemoryDatabase)
  self.database = {}
  self.backup_timestamps = {}
  self.backup_states = {}
  return self
end

function InMemoryDatabase:set_internal(key, field, value, expiry)
  if not self.database[key] then
    self.database[key] = {}
  end
  self.database[key][field] = { value, expiry }
  return ""
end

function InMemoryDatabase:alive(key, field, timestamp)
  if not self.database[key] or not self.database[key][field] then
    return false
  end
  local expiry = self.database[key][field][2]
  if expiry == nil then
    return true
  end
  return timestamp < expiry
end

function InMemoryDatabase:set(key, field, value)
  return self:set_internal(key, field, value, nil)
end

function InMemoryDatabase:get(key, field)
  if not self.database[key] or not self.database[key][field] then
    return ""
  end
  return self.database[key][field][1]
end

function InMemoryDatabase:delete(key, field)
  if not self.database[key] or not self.database[key][field] then
    return "false"
  end
  self.database[key][field] = nil
  return "true"
end

local function sorted_fields(fields)
  local names = {}
  for field in pairs(fields) do
    names[#names + 1] = field
  end
  table.sort(names)
  return names
end

function InMemoryDatabase:scan(key)
  if not self.database[key] then
    return ""
  end
  local parts = {}
  for _, field in ipairs(sorted_fields(self.database[key])) do
    parts[#parts + 1] = string.format("%s(%s)", field, self.database[key][field][1])
  end
  return table.concat(parts, ", ")
end

function InMemoryDatabase:scan_by_prefix(key, prefix)
  if not self.database[key] then
    return ""
  end
  local parts = {}
  for _, field in ipairs(sorted_fields(self.database[key])) do
    if field:sub(1, #prefix) == prefix then
      parts[#parts + 1] = string.format("%s(%s)", field, self.database[key][field][1])
    end
  end
  return table.concat(parts, ", ")
end

function InMemoryDatabase:set_at(key, field, value, timestamp)
  local _ = timestamp
  return self:set_internal(key, field, value, nil)
end

function InMemoryDatabase:set_at_with_ttl(key, field, value, timestamp, ttl)
  return self:set_internal(key, field, value, timestamp + ttl)
end

function InMemoryDatabase:delete_at(key, field, timestamp)
  if not self:alive(key, field, timestamp) then
    return "false"
  end
  self.database[key][field] = nil
  return "true"
end

function InMemoryDatabase:get_at(key, field, timestamp)
  if not self:alive(key, field, timestamp) then
    return ""
  end
  return self.database[key][field][1]
end

function InMemoryDatabase:scan_at(key, timestamp)
  if not self.database[key] then
    return ""
  end
  local parts = {}
  for _, field in ipairs(sorted_fields(self.database[key])) do
    if self:alive(key, field, timestamp) then
      parts[#parts + 1] = string.format("%s(%s)", field, self.database[key][field][1])
    end
  end
  return table.concat(parts, ", ")
end

function InMemoryDatabase:scan_by_prefix_at(key, prefix, timestamp)
  if not self.database[key] then
    return ""
  end
  local parts = {}
  for _, field in ipairs(sorted_fields(self.database[key])) do
    if field:sub(1, #prefix) == prefix and self:alive(key, field, timestamp) then
      parts[#parts + 1] = string.format("%s(%s)", field, self.database[key][field][1])
    end
  end
  return table.concat(parts, ", ")
end

function InMemoryDatabase:backup(timestamp)
  local state = {}
  local count = 0
  for key, fields in pairs(self.database) do
    for field, row in pairs(fields) do
      if self:alive(key, field, timestamp) then
        if not state[key] then
          state[key] = {}
          count = count + 1
        end
        local expiry = row[2]
        local remaining
        if expiry ~= nil then
          remaining = expiry - timestamp
        end
        state[key][field] = { row[1], remaining }
      end
    end
  end
  self.backup_timestamps[#self.backup_timestamps + 1] = timestamp
  self.backup_states[#self.backup_states + 1] = state
  return tostring(count)
end

function InMemoryDatabase:restore(timestamp, timestamp_to_restore)
  local idx = -1
  for i, ts in ipairs(self.backup_timestamps) do
    if ts <= timestamp_to_restore then
      idx = i
    end
  end
  local backup_state = self.backup_states[idx]
  self.database = {}
  for key, fields in pairs(backup_state) do
    for field, row in pairs(fields) do
      local remaining = row[2]
      local expiry
      if remaining ~= nil then
        expiry = timestamp + remaining
      end
      self:set_internal(key, field, row[1], expiry)
    end
  end
  return ""
end
