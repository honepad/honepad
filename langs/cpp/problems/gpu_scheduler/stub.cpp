// Simulation stub. Fill methods from the problem spec.
// add_gpu(gpu_id, mem)
// submit_job(job_id, mem)
// status(job_id)
// assign()
// complete(job_id)
// cancel(job_id)
// set_priority(job_id, priority)

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
