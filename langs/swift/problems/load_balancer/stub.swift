// Simulation stub. Fill methods from the problem spec.
// add_backend(backend_id)
// route()
// set_health(backend_id, flag)
// set_weight(backend_id, weight)
// sticky(client_id)
// done(backend_id)

final class Simulation: Harness {
  func call(_ method: String, _ args: [Any]) throws -> Any {
    throw HarnessError.missingMethod(method)
  }
}
