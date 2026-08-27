#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <algorithm>
#include <cstdint>
#include <deque>
#include <map>
#include <string>
#include <utility>
#include <vector>

class Account {
 public:
  std::string account_id;
  int64_t balance = 0;
  int64_t outgoing = 0;
  std::map<std::string, std::string> payments;
  int64_t created_at = 0;
  std::vector<std::pair<int64_t, int64_t>> balance_history;

  Account() = default;

  explicit Account(std::string id, int64_t created) : account_id(std::move(id)), created_at(created) {
    balance_history.emplace_back(created, 0);
  }

  void record_balance(int64_t timestamp) { balance_history.emplace_back(timestamp, balance); }

  int64_t deposit(int64_t amount) {
    balance += amount;
    return balance;
  }

  bool withdraw(int64_t amount) {
    if (balance < amount) {
      return false;
    }
    balance -= amount;
    outgoing += amount;
    return true;
  }

  std::optional<int64_t> get_balance_at(int64_t time_at) const {
    if (time_at < created_at) {
      return std::nullopt;
    }
    std::optional<int64_t> result;
    for (const auto& row : balance_history) {
      if (row.first <= time_at) {
        result = row.second;
      } else {
        break;
      }
    }
    return result;
  }
};

class Cashback {
 public:
  int64_t timestamp = 0;
  std::string account_id;
  int64_t amount = 0;
  std::string payment_id;
};

class Simulation : public Harness {
  static constexpr int64_t kCashbackDelay = 24LL * 60LL * 60LL * 1000LL;

  std::map<std::string, Account> accounts;
  int64_t payment_counter = 0;
  std::deque<Cashback> pending_cashbacks;

  void process_cashbacks(int64_t timestamp) {
    while (!pending_cashbacks.empty() && pending_cashbacks.front().timestamp <= timestamp) {
      Cashback cashback = pending_cashbacks.front();
      pending_cashbacks.pop_front();
      auto it = accounts.find(cashback.account_id);
      if (it != accounts.end()) {
        it->second.deposit(cashback.amount);
        it->second.payments[cashback.payment_id] = "CASHBACK_RECEIVED";
        it->second.record_balance(cashback.timestamp);
      }
    }
  }

  bool create_account(int64_t timestamp, const std::string& account_id) {
    process_cashbacks(timestamp);
    if (accounts.count(account_id) != 0) {
      return false;
    }
    accounts.emplace(account_id, Account(account_id, timestamp));
    return true;
  }

  std::optional<int64_t> deposit(int64_t timestamp, const std::string& account_id, int64_t amount) {
    process_cashbacks(timestamp);
    auto it = accounts.find(account_id);
    if (it == accounts.end()) {
      return std::nullopt;
    }
    int64_t result = it->second.deposit(amount);
    it->second.record_balance(timestamp);
    return result;
  }

  std::optional<int64_t> transfer(
      int64_t timestamp,
      const std::string& source_id,
      const std::string& target_id,
      int64_t amount) {
    process_cashbacks(timestamp);
    if (source_id == target_id || accounts.count(source_id) == 0 || accounts.count(target_id) == 0) {
      return std::nullopt;
    }
    if (!accounts[source_id].withdraw(amount)) {
      return std::nullopt;
    }
    accounts[target_id].deposit(amount);
    accounts[source_id].record_balance(timestamp);
    accounts[target_id].record_balance(timestamp);
    return accounts[source_id].balance;
  }

  std::vector<JsonVal> top_spenders(int64_t timestamp, int64_t n) {
    process_cashbacks(timestamp);
    std::vector<std::string> ids;
    ids.reserve(accounts.size());
    for (const auto& item : accounts) {
      ids.push_back(item.first);
    }
    std::sort(ids.begin(), ids.end(), [&](const std::string& a, const std::string& b) {
      int64_t oa = accounts[a].outgoing;
      int64_t ob = accounts[b].outgoing;
      if (oa != ob) {
        return ob < oa;
      }
      return a < b;
    });
    if (n < static_cast<int64_t>(ids.size())) {
      ids.resize(static_cast<size_t>(n));
    }
    std::vector<JsonVal> out;
    out.reserve(ids.size());
    for (const std::string& id : ids) {
      out.push_back(JsonVal::from_str(id + "(" + std::to_string(accounts[id].outgoing) + ")"));
    }
    return out;
  }

  std::optional<std::string> pay(int64_t timestamp, const std::string& account_id, int64_t amount) {
    process_cashbacks(timestamp);
    auto it = accounts.find(account_id);
    if (it == accounts.end()) {
      return std::nullopt;
    }
    if (!it->second.withdraw(amount)) {
      return std::nullopt;
    }
    payment_counter += 1;
    std::string payment_id = "payment" + std::to_string(payment_counter);
    it->second.payments[payment_id] = "IN_PROGRESS";
    it->second.record_balance(timestamp);
    Cashback cashback;
    cashback.timestamp = timestamp + kCashbackDelay;
    cashback.account_id = account_id;
    cashback.amount = (amount * 2) / 100;
    cashback.payment_id = payment_id;
    pending_cashbacks.push_back(std::move(cashback));
    return payment_id;
  }

  std::optional<std::string> get_payment_status(
      int64_t timestamp,
      const std::string& account_id,
      const std::string& payment) {
    process_cashbacks(timestamp);
    auto it = accounts.find(account_id);
    if (it == accounts.end()) {
      return std::nullopt;
    }
    auto pit = it->second.payments.find(payment);
    if (pit == it->second.payments.end()) {
      return std::nullopt;
    }
    return pit->second;
  }

  bool merge_accounts(int64_t timestamp, const std::string& keep_id, const std::string& drop_id) {
    process_cashbacks(timestamp);
    if (keep_id == drop_id || accounts.count(keep_id) == 0 || accounts.count(drop_id) == 0) {
      return false;
    }
    Account drop = std::move(accounts[drop_id]);
    accounts.erase(drop_id);
    Account& keep = accounts[keep_id];
    keep.balance += drop.balance;
    keep.outgoing += drop.outgoing;
    keep.payments.insert(drop.payments.begin(), drop.payments.end());
    keep.balance_history.insert(
        keep.balance_history.end(), drop.balance_history.begin(), drop.balance_history.end());
    std::sort(keep.balance_history.begin(), keep.balance_history.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });
    if (drop.created_at < keep.created_at) {
      keep.created_at = drop.created_at;
    }
    keep.record_balance(timestamp);
    for (auto& cashback : pending_cashbacks) {
      if (cashback.account_id == drop_id) {
        cashback.account_id = keep_id;
      }
    }
    return true;
  }

  std::optional<int64_t> get_balance(
      int64_t timestamp, const std::string& account_id, int64_t time_at) {
    process_cashbacks(timestamp);
    auto it = accounts.find(account_id);
    if (it == accounts.end()) {
      return std::nullopt;
    }
    return it->second.get_balance_at(time_at);
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    if (method == "createAccount") {
      return JsonVal::from_bool(create_account(arg_i64(args, 0), arg_str(args, 1)));
    }
    if (method == "deposit") {
      return opt_i64(deposit(arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2)));
    }
    if (method == "transfer") {
      return opt_i64(
          transfer(arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2), arg_i64(args, 3)));
    }
    if (method == "topSpenders") {
      return JsonVal::from_arr(top_spenders(arg_i64(args, 0), arg_i64(args, 1)));
    }
    if (method == "pay") {
      return opt_str(pay(arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2)));
    }
    if (method == "getPaymentStatus") {
      return opt_str(get_payment_status(arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2)));
    }
    if (method == "mergeAccounts") {
      return JsonVal::from_bool(merge_accounts(arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2)));
    }
    if (method == "getBalance") {
      return opt_i64(get_balance(arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2)));
    }
    throw std::runtime_error("missing method " + method);
  }
};

#endif
