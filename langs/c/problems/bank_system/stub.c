// Simulation stub. Fill methods from the problem spec.
// create_account(timestamp, account_id)
// deposit(timestamp, account_id, amount)
// transfer(timestamp, source_account_id, target_account_id, amount)
// top_spenders(timestamp, n)
// pay(timestamp, account_id, amount)
// get_payment_status(timestamp, account_id, payment)
// merge_accounts(timestamp, account_id_1, account_id_2)
// get_balance(timestamp, account_id, time_at)

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
