-- Simulation stub. Fill methods from the problem spec.
-- add_gpu(gpu_id, mem)
-- submit_job(job_id, mem)
-- status(job_id)
-- assign()
-- complete(job_id)
-- cancel(job_id)
-- set_priority(job_id, priority)
module Solution (Simulation, newTarget) where

import Harness

data Simulation = Simulation

newTarget :: Simulation
newTarget = Simulation

instance Target Simulation
