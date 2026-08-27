-- Simulation stub. Fill methods from the problem spec.
-- add_worker(worker_id, position, compensation)
-- register(worker_id, timestamp)
-- get(worker_id)
-- top_n_workers(n, position)
-- promote(worker_id, new_position, new_compensation, start_timestamp)
-- calc_salary(worker_id, start_timestamp, end_timestamp)
Simulation = {}
Simulation.__index = Simulation
function Simulation.new()
  return setmetatable({}, Simulation)
end
