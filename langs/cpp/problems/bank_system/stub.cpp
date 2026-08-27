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

#include "harness.hpp"

class Simulation : public Harness {
 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>&) override {
    throw std::runtime_error("not implemented: " + method);
  }
};

#endif
