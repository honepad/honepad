#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <map>
#include <optional>
#include <string>

class KeyState {
 public:
  int64_t limit = 3;
  int64_t window = 10;
  std::optional<int64_t> window_id;
  int64_t used = 0;
};

class Simulation : public Harness {
  std::map<std::string, KeyState> keys;

  KeyState& state(const std::string& key) {
    auto it = keys.find(key);
    if (it == keys.end()) {
      it = keys.emplace(key, KeyState{}).first;
    }
    return it->second;
  }

  static int64_t used_at(KeyState& item, int64_t timestamp, bool persist) {
    int64_t window_id = timestamp / item.window;
    if (!item.window_id.has_value() || window_id != *item.window_id) {
      if (persist) {
        item.window_id = window_id;
        item.used = 0;
      }
      return 0;
    }
    return item.used;
  }

  std::string allow(const std::string& key, int64_t timestamp) {
    return allow_weighted(key, 1, timestamp);
  }

  std::string configure(const std::string& key, int64_t limit, int64_t window) {
    if (limit <= 0 || window <= 0) {
      return "invalid_request";
    }
    KeyState& item = state(key);
    item.limit = limit;
    item.window = window;
    item.window_id.reset();
    item.used = 0;
    return "true";
  }

  std::string remaining(const std::string& key, int64_t timestamp) {
    KeyState& item = state(key);
    int64_t used = used_at(item, timestamp, false);
    return std::to_string(item.limit - used);
  }

  std::string allow_weighted(const std::string& key, int64_t cost, int64_t timestamp) {
    if (cost <= 0) {
      return "invalid_request";
    }
    KeyState& item = state(key);
    used_at(item, timestamp, true);
    if (item.used + cost > item.limit) {
      return "false";
    }
    item.used += cost;
    return "true";
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "allow") {
      text = allow(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "configure") {
      text = configure(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2));
    } else if (method == "remaining") {
      text = remaining(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "allowWeighted") {
      text = allow_weighted(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
