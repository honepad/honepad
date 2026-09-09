// Simulation stub. Fill methods from the problem spec.
// add_backend(backend_id)
// route()
// set_health(backend_id, flag)
// set_weight(backend_id, weight)
// sticky(client_id)
// done(backend_id)

#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

class Simulation : public Harness {
 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>&) override {
    throw std::runtime_error("not implemented: " + method);
  }
};

#endif
