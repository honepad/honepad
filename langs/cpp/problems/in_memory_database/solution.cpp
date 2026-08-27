#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <map>
#include <optional>
#include <string>
#include <vector>

class FieldVal {
 public:
  std::string value;
  std::optional<int64_t> expiry;
};

class InMemoryDatabase : public Harness {
  std::map<std::string, std::map<std::string, FieldVal>> database;
  std::vector<int64_t> backup_timestamps;
  std::vector<std::map<std::string, std::map<std::string, FieldVal>>> backup_states;

  std::string set_internal(
      const std::string& key,
      const std::string& field,
      const std::string& value,
      std::optional<int64_t> expiry) {
    database[key][field] = FieldVal{value, expiry};
    return "";
  }

  bool is_alive(const std::string& key, const std::string& field, int64_t timestamp) const {
    auto kit = database.find(key);
    if (kit == database.end()) {
      return false;
    }
    auto fit = kit->second.find(field);
    if (fit == kit->second.end()) {
      return false;
    }
    if (!fit->second.expiry) {
      return true;
    }
    return timestamp < *fit->second.expiry;
  }

  std::string get(const std::string& key, const std::string& field) const {
    auto kit = database.find(key);
    if (kit == database.end()) {
      return "";
    }
    auto fit = kit->second.find(field);
    if (fit == kit->second.end()) {
      return "";
    }
    return fit->second.value;
  }

  std::string del(const std::string& key, const std::string& field) {
    auto kit = database.find(key);
    if (kit == database.end() || kit->second.count(field) == 0) {
      return "false";
    }
    kit->second.erase(field);
    return "true";
  }

  std::string format_scan(const std::vector<std::string>& names,
                          const std::map<std::string, FieldVal>& fields) const {
    std::string out;
    for (size_t i = 0; i < names.size(); i++) {
      if (i > 0) {
        out += ", ";
      }
      out += names[i] + "(" + fields.at(names[i]).value + ")";
    }
    return out;
  }

  std::string scan(const std::string& key) const {
    auto kit = database.find(key);
    if (kit == database.end()) {
      return "";
    }
    std::vector<std::string> names;
    for (const auto& item : kit->second) {
      names.push_back(item.first);
    }
    return format_scan(names, kit->second);
  }

  std::string scan_by_prefix(const std::string& key, const std::string& prefix) const {
    auto kit = database.find(key);
    if (kit == database.end()) {
      return "";
    }
    std::vector<std::string> names;
    for (const auto& item : kit->second) {
      if (item.first.compare(0, prefix.size(), prefix) == 0) {
        names.push_back(item.first);
      }
    }
    return format_scan(names, kit->second);
  }

  std::string delete_at(const std::string& key, const std::string& field, int64_t timestamp) {
    if (!is_alive(key, field, timestamp)) {
      return "false";
    }
    database[key].erase(field);
    return "true";
  }

  std::string get_at(const std::string& key, const std::string& field, int64_t timestamp) const {
    if (!is_alive(key, field, timestamp)) {
      return "";
    }
    return database.at(key).at(field).value;
  }

  std::string scan_at(const std::string& key, int64_t timestamp) const {
    auto kit = database.find(key);
    if (kit == database.end()) {
      return "";
    }
    std::vector<std::string> names;
    for (const auto& item : kit->second) {
      if (is_alive(key, item.first, timestamp)) {
        names.push_back(item.first);
      }
    }
    return format_scan(names, kit->second);
  }

  std::string scan_by_prefix_at(
      const std::string& key, const std::string& prefix, int64_t timestamp) const {
    auto kit = database.find(key);
    if (kit == database.end()) {
      return "";
    }
    std::vector<std::string> names;
    for (const auto& item : kit->second) {
      if (item.first.compare(0, prefix.size(), prefix) == 0 && is_alive(key, item.first, timestamp)) {
        names.push_back(item.first);
      }
    }
    return format_scan(names, kit->second);
  }

  std::string backup(int64_t timestamp) {
    std::map<std::string, std::map<std::string, FieldVal>> state;
    for (const auto& key_item : database) {
      for (const auto& field_item : key_item.second) {
        if (!is_alive(key_item.first, field_item.first, timestamp)) {
          continue;
        }
        FieldVal stored;
        stored.value = field_item.second.value;
        if (field_item.second.expiry) {
          stored.expiry = *field_item.second.expiry - timestamp;
        }
        state[key_item.first][field_item.first] = stored;
      }
    }
    backup_timestamps.push_back(timestamp);
    backup_states.push_back(state);
    return std::to_string(state.size());
  }

  std::string restore(int64_t timestamp, int64_t timestamp_to_restore) {
    int idx = -1;
    for (size_t i = 0; i < backup_timestamps.size(); i++) {
      if (backup_timestamps[i] <= timestamp_to_restore) {
        idx = static_cast<int>(i);
      }
    }
    database.clear();
    if (idx < 0) {
      return "";
    }
    const auto& backup = backup_states[static_cast<size_t>(idx)];
    for (const auto& key_item : backup) {
      for (const auto& field_item : key_item.second) {
        std::optional<int64_t> expiry;
        if (field_item.second.expiry) {
          expiry = timestamp + *field_item.second.expiry;
        }
        set_internal(key_item.first, field_item.first, field_item.second.value, expiry);
      }
    }
    return "";
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "set") {
      text = set_internal(arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), std::nullopt);
    } else if (method == "get") {
      text = get(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "delete") {
      text = del(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "scan") {
      text = scan(arg_str(args, 0));
    } else if (method == "scanByPrefix") {
      text = scan_by_prefix(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "setAt") {
      text = set_internal(arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), std::nullopt);
    } else if (method == "setAtWithTtl") {
      text = set_internal(
          arg_str(args, 0),
          arg_str(args, 1),
          arg_str(args, 2),
          arg_i64(args, 3) + arg_i64(args, 4));
    } else if (method == "deleteAt") {
      text = delete_at(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2));
    } else if (method == "getAt") {
      text = get_at(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2));
    } else if (method == "scanAt") {
      text = scan_at(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "scanByPrefixAt") {
      text = scan_by_prefix_at(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2));
    } else if (method == "backup") {
      text = backup(arg_i64(args, 0));
    } else if (method == "restore") {
      text = restore(arg_i64(args, 0), arg_i64(args, 1));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
