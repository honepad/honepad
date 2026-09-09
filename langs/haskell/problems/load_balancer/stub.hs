-- Simulation stub. Fill methods from the problem spec.
-- add_backend(backend_id)
-- route()
-- set_health(backend_id, flag)
-- set_weight(backend_id, weight)
-- sticky(client_id)
-- done(backend_id)
module Solution (Simulation, newTarget) where

import Harness

data Simulation = Simulation

newTarget :: Simulation
newTarget = Simulation

instance Target Simulation
