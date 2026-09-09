-- Simulation stub. Fill methods from the problem spec.
-- allow(key, timestamp)
-- configure(key, limit, window)
-- remaining(key, timestamp)
-- allow_weighted(key, cost, timestamp)
Simulation = {}
Simulation.__index = Simulation
function Simulation.new()
  return setmetatable({}, Simulation)
end
