#ifndef HONEPAD_HARNESS_HPP
#define HONEPAD_HARNESS_HPP

#include "minijson.hpp"

#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

struct Harness {
  virtual ~Harness() = default;
  virtual JsonVal call(const std::string& method, const std::vector<JsonVal>& args) = 0;
};

Harness* new_target();

inline int64_t arg_i64(const std::vector<JsonVal>& args, size_t index) {
  if (index >= args.size()) {
    throw std::runtime_error("missing arg " + std::to_string(index));
  }
  return args[index].as_i64();
}

inline std::string arg_str(const std::vector<JsonVal>& args, size_t index) {
  if (index >= args.size()) {
    throw std::runtime_error("missing arg " + std::to_string(index));
  }
  return args[index].as_str();
}

inline JsonVal opt_i64(const std::optional<int64_t>& value) {
  if (!value) {
    return JsonVal::nullv();
  }
  return JsonVal::from_int(*value);
}

inline JsonVal opt_str(const std::optional<std::string>& value) {
  if (!value) {
    return JsonVal::nullv();
  }
  return JsonVal::from_str(*value);
}

#endif
