-- Simulation stub. Fill methods from the problem spec.
-- create_item(sku, name)
-- stock(sku, delta)
-- get_qty(sku)
-- list_low(threshold)
-- reserve(sku, n)
-- release(sku, n)
-- ship(sku, n)
Simulation = {}
Simulation.__index = Simulation
function Simulation.new()
  return setmetatable({}, Simulation)
end
