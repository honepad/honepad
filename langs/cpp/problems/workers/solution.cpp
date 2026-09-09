#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <algorithm>
#include <map>
#include <optional>
#include <string>
#include <vector>

class WorkSession {
 public:
  int64_t start = 0;
  int64_t end = 0;
  int64_t rate = 0;
  std::string position;
};

class Promo {
 public:
  std::string position;
  int64_t compensation = 0;
  int64_t start_timestamp = 0;
};

class PayWindow {
 public:
  int64_t begin = 0;
  int64_t end = 0;
};

class Worker {
 public:
  std::string worker_id;
  std::string position;
  int64_t compensation = 0;
  bool in_office = false;
  std::optional<int64_t> entered_at;
  std::vector<WorkSession> finished;
  std::optional<Promo> pending_promo;
  std::vector<PayWindow> double_pay;

  int64_t total_time() const {
    int64_t sum = 0;
    for (const auto& session : finished) {
      sum += session.end - session.start;
    }
    return sum;
  }

  int64_t position_time(const std::string& pos) const {
    int64_t sum = 0;
    for (const auto& session : finished) {
      if (session.position == pos) {
        sum += session.end - session.start;
      }
    }
    return sum;
  }

  void apply_promo_on_enter(int64_t timestamp) {
    if (!pending_promo) {
      return;
    }
    if (timestamp >= pending_promo->start_timestamp) {
      position = pending_promo->position;
      compensation = pending_promo->compensation;
      pending_promo.reset();
    }
  }
};

class Simulation : public Harness {
  std::map<std::string, Worker> workers;

  std::string add_worker(
      const std::string& worker_id, const std::string& position, int64_t compensation) {
    if (workers.count(worker_id) != 0) {
      return "false";
    }
    Worker worker;
    worker.worker_id = worker_id;
    worker.position = position;
    worker.compensation = compensation;
    workers.emplace(worker_id, std::move(worker));
    return "true";
  }

  std::string register_worker(const std::string& worker_id, int64_t timestamp) {
    auto it = workers.find(worker_id);
    if (it == workers.end()) {
      return "invalid_request";
    }
    Worker& worker = it->second;
    if (worker.in_office) {
      WorkSession session;
      session.start = *worker.entered_at;
      session.end = timestamp;
      session.rate = worker.compensation;
      session.position = worker.position;
      worker.finished.push_back(std::move(session));
      worker.in_office = false;
      worker.entered_at.reset();
      return "registered";
    }
    worker.apply_promo_on_enter(timestamp);
    worker.in_office = true;
    worker.entered_at = timestamp;
    return "registered";
  }

  std::string get(const std::string& worker_id) const {
    auto it = workers.find(worker_id);
    if (it == workers.end()) {
      return "";
    }
    return std::to_string(it->second.total_time());
  }

  std::string top_n_workers(int64_t n, const std::string& position) const {
    std::vector<const Worker*> matched;
    for (const auto& item : workers) {
      if (item.second.position == position) {
        matched.push_back(&item.second);
      }
    }
    std::sort(matched.begin(), matched.end(), [&](const Worker* a, const Worker* b) {
      int64_t ta = a->position_time(position);
      int64_t tb = b->position_time(position);
      if (ta != tb) {
        return tb < ta;
      }
      return a->worker_id < b->worker_id;
    });
    if (n < static_cast<int64_t>(matched.size())) {
      matched.resize(static_cast<size_t>(n));
    }
    std::string out;
    for (size_t i = 0; i < matched.size(); i++) {
      if (i > 0) {
        out += ", ";
      }
      out += matched[i]->worker_id + "(" + std::to_string(matched[i]->position_time(position)) + ")";
    }
    return out;
  }

  std::string promote(
      const std::string& worker_id,
      const std::string& new_position,
      int64_t new_compensation,
      int64_t start_timestamp) {
    auto it = workers.find(worker_id);
    if (it == workers.end() || it->second.pending_promo) {
      return "invalid_request";
    }
    Promo promo;
    promo.position = new_position;
    promo.compensation = new_compensation;
    promo.start_timestamp = start_timestamp;
    it->second.pending_promo = std::move(promo);
    return "success";
  }

  static int64_t bonus_overlap(int64_t lo, int64_t hi, const std::vector<PayWindow>& windows) {
    std::vector<PayWindow> segs;
    for (const auto& window : windows) {
      int64_t start = std::max(lo, window.begin);
      int64_t stop = std::min(hi, window.end);
      if (stop > start) {
        PayWindow seg;
        seg.begin = start;
        seg.end = stop;
        segs.push_back(seg);
      }
    }
    std::sort(segs.begin(), segs.end(), [](const PayWindow& a, const PayWindow& b) {
      return a.begin < b.begin;
    });
    std::vector<PayWindow> merged;
    for (const auto& seg : segs) {
      if (merged.empty() || seg.begin >= merged.back().end) {
        merged.push_back(seg);
      } else {
        merged.back().end = std::max(merged.back().end, seg.end);
      }
    }
    int64_t sum = 0;
    for (const auto& seg : merged) {
      sum += seg.end - seg.begin;
    }
    return sum;
  }

  std::string set_double_pay(
      const std::string& worker_id, int64_t interval_begin, int64_t interval_end) {
    auto it = workers.find(worker_id);
    if (it == workers.end() || interval_end <= interval_begin) {
      return "invalid_request";
    }
    PayWindow window;
    window.begin = interval_begin;
    window.end = interval_end;
    it->second.double_pay.push_back(window);
    return "true";
  }

  std::string calc_salary(
      const std::string& worker_id, int64_t start_timestamp, int64_t end_timestamp) const {
    auto it = workers.find(worker_id);
    if (it == workers.end()) {
      return "";
    }
    int64_t total = 0;
    for (const auto& session : it->second.finished) {
      int64_t lo = std::max(session.start, start_timestamp);
      int64_t hi = std::min(session.end, end_timestamp);
      if (hi > lo) {
        int64_t bonus = bonus_overlap(lo, hi, it->second.double_pay);
        total += (hi - lo - bonus) * session.rate + bonus * session.rate * 2;
      }
    }
    return std::to_string(total);
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "addWorker") {
      text = add_worker(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2));
    } else if (method == "register") {
      text = register_worker(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "get") {
      text = get(arg_str(args, 0));
    } else if (method == "topNWorkers") {
      text = top_n_workers(arg_i64(args, 0), arg_str(args, 1));
    } else if (method == "promote") {
      text = promote(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2), arg_i64(args, 3));
    } else if (method == "setDoublePay") {
      text = set_double_pay(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2));
    } else if (method == "calcSalary") {
      text = calc_salary(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
