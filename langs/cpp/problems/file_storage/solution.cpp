#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <algorithm>
#include <map>
#include <optional>
#include <string>
#include <vector>

class StoredFile {
 public:
  std::string name;
  int64_t size = 0;
  std::string owner;
};

class Simulation : public Harness {
  std::map<std::string, StoredFile> files;
  std::vector<std::string> file_order;
  std::map<std::string, std::optional<int64_t>> capacity;
  std::map<std::string, std::vector<std::pair<std::string, int64_t>>> backups;

  int64_t used(const std::string& user_id) const {
    int64_t sum = 0;
    for (const auto& item : files) {
      if (item.second.owner == user_id) {
        sum += item.second.size;
      }
    }
    return sum;
  }

  std::optional<int64_t> remaining(const std::string& user_id) const {
    auto it = capacity.find(user_id);
    if (it == capacity.end() || !it->second) {
      return std::nullopt;
    }
    return *it->second - used(user_id);
  }

  std::string add_file(const std::string& name, int64_t size) {
    if (files.count(name) != 0) {
      return "false";
    }
    files[name] = StoredFile{name, size, "admin"};
    file_order.push_back(name);
    return "true";
  }

  std::string get_file_size(const std::string& name) const {
    auto it = files.find(name);
    if (it == files.end()) {
      return "";
    }
    return std::to_string(it->second.size);
  }

  std::string delete_file(const std::string& name) {
    auto it = files.find(name);
    if (it == files.end()) {
      return "";
    }
    int64_t size = it->second.size;
    files.erase(it);
    file_order.erase(std::remove(file_order.begin(), file_order.end(), name), file_order.end());
    return std::to_string(size);
  }

  std::string copy_file(const std::string& source, const std::string& dest) {
    auto sit = files.find(source);
    if (sit == files.end()) {
      return "";
    }
    int64_t src_size = sit->second.size;
    if (source == dest) {
      return std::to_string(src_size);
    }
    auto dit = files.find(dest);
    std::string owner = dit == files.end() ? sit->second.owner : dit->second.owner;
    int64_t extra = dit == files.end() ? src_size : src_size - dit->second.size;
    auto left = remaining(owner);
    if (left && extra > *left) {
      return "";
    }
    if (dit == files.end()) {
      files[dest] = StoredFile{dest, src_size, owner};
      file_order.push_back(dest);
    } else {
      dit->second.size = src_size;
    }
    return std::to_string(src_size);
  }

  std::string get_n_largest(const std::string& prefix, int64_t n) const {
    std::vector<const StoredFile*> matched;
    for (const auto& item : files) {
      if (item.second.name.compare(0, prefix.size(), prefix) == 0) {
        matched.push_back(&item.second);
      }
    }
    std::sort(matched.begin(), matched.end(), [](const StoredFile* a, const StoredFile* b) {
      if (a->size != b->size) {
        return b->size < a->size;
      }
      return a->name < b->name;
    });
    if (n < static_cast<int64_t>(matched.size())) {
      matched.resize(static_cast<size_t>(n));
    }
    std::string out;
    for (size_t i = 0; i < matched.size(); i++) {
      if (i > 0) {
        out += ", ";
      }
      out += matched[i]->name + "(" + std::to_string(matched[i]->size) + ")";
    }
    return out;
  }

  std::string add_user(const std::string& user_id, int64_t cap) {
    if (capacity.count(user_id) != 0) {
      return "false";
    }
    capacity[user_id] = cap;
    return "true";
  }

  std::string add_file_by(const std::string& user_id, const std::string& name, int64_t size) {
    if (capacity.count(user_id) == 0 || files.count(name) != 0) {
      return "";
    }
    auto left = remaining(user_id);
    if (left && size > *left) {
      return "";
    }
    files[name] = StoredFile{name, size, user_id};
    file_order.push_back(name);
    auto after = remaining(user_id);
    return after ? std::to_string(*after) : "";
  }

  std::string merge_user(const std::string& user_id1, const std::string& user_id2) {
    if (user_id1 == user_id2) {
      return "";
    }
    auto it1 = capacity.find(user_id1);
    auto it2 = capacity.find(user_id2);
    if (it1 == capacity.end() || it2 == capacity.end() || !it1->second || !it2->second) {
      return "";
    }
    capacity[user_id1] = *it1->second + *it2->second;
    for (auto& item : files) {
      if (item.second.owner == user_id2) {
        item.second.owner = user_id1;
      }
    }
    capacity.erase(user_id2);
    backups.erase(user_id2);
    auto left = remaining(user_id1);
    return left ? std::to_string(*left) : "";
  }

  std::string backup_user(const std::string& user_id) {
    if (capacity.count(user_id) == 0) {
      return "";
    }
    std::vector<std::pair<std::string, int64_t>> snap;
    for (const std::string& name : file_order) {
      auto it = files.find(name);
      if (it != files.end() && it->second.owner == user_id) {
        snap.emplace_back(name, it->second.size);
      }
    }
    std::string count = std::to_string(snap.size());
    backups[user_id] = std::move(snap);
    return count;
  }

  std::string restore_user(const std::string& user_id) {
    if (capacity.count(user_id) == 0) {
      return "";
    }
    std::vector<std::string> owned;
    for (const auto& item : files) {
      if (item.second.owner == user_id) {
        owned.push_back(item.first);
      }
    }
    for (const std::string& name : owned) {
      files.erase(name);
      file_order.erase(std::remove(file_order.begin(), file_order.end(), name), file_order.end());
    }
    auto bit = backups.find(user_id);
    if (bit == backups.end()) {
      return "0";
    }
    int64_t restored = 0;
    for (const auto& item : bit->second) {
      if (files.count(item.first) != 0) {
        continue;
      }
      auto left = remaining(user_id);
      if (left && item.second > *left) {
        continue;
      }
      files[item.first] = StoredFile{item.first, item.second, user_id};
      file_order.push_back(item.first);
      restored += 1;
    }
    return std::to_string(restored);
  }

 public:
  Simulation() { capacity["admin"] = std::nullopt; }

  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "addFile") {
      text = add_file(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "copyFile") {
      text = copy_file(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "getFileSize") {
      text = get_file_size(arg_str(args, 0));
    } else if (method == "deleteFile") {
      text = delete_file(arg_str(args, 0));
    } else if (method == "getNLargest") {
      text = get_n_largest(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "addUser") {
      text = add_user(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "addFileBy") {
      text = add_file_by(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2));
    } else if (method == "mergeUser") {
      text = merge_user(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "backupUser") {
      text = backup_user(arg_str(args, 0));
    } else if (method == "restoreUser") {
      text = restore_user(arg_str(args, 0));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
