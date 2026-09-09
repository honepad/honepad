// Simulation stub. Fill methods from the problem spec.
// add_gpu(gpu_id, mem)
// submit_job(job_id, mem)
// status(job_id)
// assign()
// complete(job_id)
// cancel(job_id)
// set_priority(job_id, priority)

final class Simulation: Harness {
  func call(_ method: String, _ args: [Any]) throws -> Any {
    throw HarnessError.missingMethod(method)
  }
}
