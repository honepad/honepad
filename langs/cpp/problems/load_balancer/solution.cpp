#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <map>
#include <string>
#include <vector>

class Backend {
 public:
  std::string backend_id;
  bool health = true;
  int64_t weight = 1;
  int64_t inflight = 0;
};

class Simulation : public Harness {
  std::vector<Backend> backends;
  std::map<std::string, size_t> by_id;
  int64_t cursor = 0;
  std::map<std::string, std::string> sticky_map;
  bool use_least = false;

  std::string add_backend(const std::string& backend_id) {
    if (by_id.count(backend_id) != 0) {
      return "false";
    }
    Backend item;
    item.backend_id = backend_id;
    by_id[backend_id] = backends.size();
    backends.push_back(item);
    return "true";
  }

  std::string set_health(const std::string& backend_id, int64_t flag) {
    auto it = by_id.find(backend_id);
    if (it == by_id.end() || (flag != 0 && flag != 1)) {
      return "invalid_request";
    }
    backends[it->second].health = flag == 1;
    reset_cycle();
    return "true";
  }

  std::string set_weight(const std::string& backend_id, int64_t weight) {
    auto it = by_id.find(backend_id);
    if (it == by_id.end() || weight <= 0) {
      return "invalid_request";
    }
    backends[it->second].weight = weight;
    reset_cycle();
    return "true";
  }

  void reset_cycle() {
    cursor = 0;
    use_least = false;
    for (Backend& item : backends) {
      item.inflight = 0;
    }
  }

  std::vector<size_t> tickets(const std::vector<size_t>& items) const {
    std::vector<size_t> out;
    for (size_t idx : items) {
      for (int64_t n = 0; n < backends[idx].weight; n++) {
        out.push_back(idx);
      }
    }
    return out;
  }

  Backend* pick() {
    std::vector<size_t> healthy;
    for (size_t i = 0; i < backends.size(); i++) {
      if (backends[i].health) {
        healthy.push_back(i);
      }
    }
    if (healthy.empty()) {
      return nullptr;
    }
    std::vector<size_t> pool = healthy;
    if (use_least) {
      int64_t least = backends[healthy[0]].inflight;
      for (size_t i = 1; i < healthy.size(); i++) {
        if (backends[healthy[i]].inflight < least) {
          least = backends[healthy[i]].inflight;
        }
      }
      pool.clear();
      for (size_t idx : healthy) {
        if (backends[idx].inflight == least) {
          pool.push_back(idx);
        }
      }
    }
    std::vector<size_t> ticket_list = tickets(pool);
    if (ticket_list.empty()) {
      return nullptr;
    }
    Backend* chosen = &backends[ticket_list[static_cast<size_t>(cursor) % ticket_list.size()]];
    cursor += 1;
    return chosen;
  }

  std::string take() {
    Backend* item = pick();
    if (item == nullptr) {
      return "";
    }
    item->inflight += 1;
    return item->backend_id;
  }

  std::string route() { return take(); }

  std::string sticky(const std::string& client_id) {
    auto sit = sticky_map.find(client_id);
    if (sit != sticky_map.end()) {
      auto bit = by_id.find(sit->second);
      if (bit != by_id.end() && backends[bit->second].health) {
        backends[bit->second].inflight += 1;
        return backends[bit->second].backend_id;
      }
    }
    std::string chosen = take();
    if (!chosen.empty()) {
      sticky_map[client_id] = chosen;
    }
    return chosen;
  }

  std::string done(const std::string& backend_id) {
    auto it = by_id.find(backend_id);
    if (it == by_id.end() || backends[it->second].inflight <= 0) {
      return "invalid_request";
    }
    backends[it->second].inflight -= 1;
    use_least = true;
    return "true";
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "addBackend") {
      text = add_backend(arg_str(args, 0));
    } else if (method == "route") {
      text = route();
    } else if (method == "setHealth") {
      text = set_health(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "setWeight") {
      text = set_weight(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "sticky") {
      text = sticky(arg_str(args, 0));
    } else if (method == "done") {
      text = done(arg_str(args, 0));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
