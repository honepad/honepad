#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <algorithm>
#include <map>
#include <string>
#include <vector>

class Item {
 public:
  std::string sku;
  std::string name;
  int64_t qty = 0;
  int64_t reserved = 0;
};

class Simulation : public Harness {
  std::map<std::string, Item> items;

  std::string create_item(const std::string& sku, const std::string& name) {
    if (items.count(sku) != 0) {
      return "false";
    }
    items[sku] = Item{sku, name, 0, 0};
    return "true";
  }

  std::string stock(const std::string& sku, int64_t delta) {
    auto it = items.find(sku);
    if (it == items.end()) {
      return "";
    }
    int64_t nxt = it->second.qty + delta;
    if (nxt < it->second.reserved) {
      return "invalid_request";
    }
    it->second.qty = nxt;
    return std::to_string(it->second.qty);
  }

  std::string get_qty(const std::string& sku) const {
    auto it = items.find(sku);
    if (it == items.end()) {
      return "";
    }
    return std::to_string(it->second.qty);
  }

  std::string list_low(int64_t threshold) const {
    std::vector<const Item*> matched;
    for (const auto& entry : items) {
      if (entry.second.qty <= threshold) {
        matched.push_back(&entry.second);
      }
    }
    std::sort(matched.begin(), matched.end(), [](const Item* a, const Item* b) {
      if (a->qty != b->qty) {
        return a->qty < b->qty;
      }
      return a->sku < b->sku;
    });
    std::string out;
    for (size_t i = 0; i < matched.size(); i++) {
      if (i > 0) {
        out += ", ";
      }
      out += matched[i]->sku + "(" + std::to_string(matched[i]->qty) + ")";
    }
    return out;
  }

  std::string reserve(const std::string& sku, int64_t n) {
    auto it = items.find(sku);
    if (it == items.end() || n <= 0 || it->second.reserved + n > it->second.qty) {
      return "invalid_request";
    }
    it->second.reserved += n;
    return "true";
  }

  std::string release(const std::string& sku, int64_t n) {
    auto it = items.find(sku);
    if (it == items.end() || n <= 0 || n > it->second.reserved) {
      return "invalid_request";
    }
    it->second.reserved -= n;
    return "true";
  }

  std::string ship(const std::string& sku, int64_t n) {
    auto it = items.find(sku);
    if (it == items.end() || n <= 0 || n > it->second.reserved) {
      return "invalid_request";
    }
    it->second.reserved -= n;
    it->second.qty -= n;
    return "true";
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "createItem") {
      text = create_item(arg_str(args, 0), arg_str(args, 1));
    } else if (method == "stock") {
      text = stock(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "getQty") {
      text = get_qty(arg_str(args, 0));
    } else if (method == "listLow") {
      text = list_low(arg_i64(args, 0));
    } else if (method == "reserve") {
      text = reserve(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "release") {
      text = release(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "ship") {
      text = ship(arg_str(args, 0), arg_i64(args, 1));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
