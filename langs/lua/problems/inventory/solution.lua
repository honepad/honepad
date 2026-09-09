Item = {}
Item.__index = Item

function Item.new(sku, name)
  local self = setmetatable({}, Item)
  self.sku = sku
  self.name = name
  self.qty = 0
  self.reserved = 0
  return self
end

Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.items = {}
  return self
end

function Simulation:create_item(sku, name)
  if self.items[sku] then
    return "false"
  end
  self.items[sku] = Item.new(sku, name)
  return "true"
end

function Simulation:stock(sku, delta)
  local item = self.items[sku]
  if not item then
    return ""
  end
  local nxt = item.qty + delta
  if nxt < item.reserved then
    return "invalid_request"
  end
  item.qty = nxt
  return tostring(item.qty)
end

function Simulation:get_qty(sku)
  local item = self.items[sku]
  if not item then
    return ""
  end
  return tostring(item.qty)
end

function Simulation:list_low(threshold)
  local matched = {}
  for _, item in pairs(self.items) do
    if item.qty <= threshold then
      matched[#matched + 1] = item
    end
  end
  table.sort(matched, function(a, b)
    if a.qty ~= b.qty then
      return a.qty < b.qty
    end
    return a.sku < b.sku
  end)
  local parts = {}
  for i, item in ipairs(matched) do
    parts[i] = string.format("%s(%d)", item.sku, item.qty)
  end
  return table.concat(parts, ", ")
end

function Simulation:reserve(sku, n)
  local item = self.items[sku]
  if not item or n <= 0 or item.reserved + n > item.qty then
    return "invalid_request"
  end
  item.reserved = item.reserved + n
  return "true"
end

function Simulation:release(sku, n)
  local item = self.items[sku]
  if not item or n <= 0 or n > item.reserved then
    return "invalid_request"
  end
  item.reserved = item.reserved - n
  return "true"
end

function Simulation:ship(sku, n)
  local item = self.items[sku]
  if not item or n <= 0 or n > item.reserved then
    return "invalid_request"
  end
  item.reserved = item.reserved - n
  item.qty = item.qty - n
  return "true"
end
