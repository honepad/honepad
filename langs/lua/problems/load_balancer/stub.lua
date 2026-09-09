-- Simulation stub. Fill methods from the problem spec.
-- add_backend(backend_id)
-- route()
-- set_health(backend_id, flag)
-- set_weight(backend_id, weight)
-- sticky(client_id)
-- done(backend_id)
Simulation = {}
Simulation.__index = Simulation
function Simulation.new()
  return setmetatable({}, Simulation)
end
