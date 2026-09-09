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

#include "harness.h"

typedef struct {
  HonepadTarget base;
} Simulation;

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  (void)self;
  (void)args;
  char buf[256];
  snprintf(buf, sizeof(buf), "not implemented: %s", method);
  honepad_throw(buf);
  return json_null();
}

static void simulation_free(HonepadTarget *self) { free(self); }

static HonepadTarget *Simulation_new(void) {
  Simulation *sim = calloc(1, sizeof(*sim));
  if (sim == NULL) {
    fprintf(stderr, "oom\n");
    exit(2);
  }
  sim->base.call = simulation_call;
  sim->base.free_fn = simulation_free;
  return &sim->base;
}

#endif
