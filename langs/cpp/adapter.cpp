#include "harness.hpp"
#include "minijson.hpp"

#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace {

std::string read_file(const std::string& path) {
  std::ifstream in(path);
  if (!in) {
    throw std::runtime_error("cannot read " + path);
  }
  std::ostringstream buf;
  buf << in.rdbuf();
  return buf.str();
}

std::string to_camel(const std::string& snake) {
  if (snake.find('_') == std::string::npos) {
    return snake;
  }
  std::string out;
  bool upper = false;
  for (char ch : snake) {
    if (ch == '_') {
      upper = true;
      continue;
    }
    if (upper && !out.empty()) {
      out += static_cast<char>(std::toupper(static_cast<unsigned char>(ch)));
      upper = false;
    } else {
      out += ch;
      upper = false;
    }
  }
  return out;
}

JsonVal fail_row(
    const std::string& case_id,
    int64_t index,
    const std::string& method,
    const JsonVal& expected,
    const JsonVal& actual) {
  JsonVal row;
  row.type = JsonVal::TObj;
  row.obj.emplace_back("case", JsonVal::from_str(case_id));
  row.obj.emplace_back("index", JsonVal::from_int(index));
  row.obj.emplace_back("method", JsonVal::from_str(method));
  row.obj.emplace_back("expected", expected);
  row.obj.emplace_back("actual", actual);
  return row;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "usage: adapter cases.json\n";
    return 2;
  }
  JsonVal cases;
  try {
    cases = parse_json(read_file(argv[1]));
  } catch (const std::exception& err) {
    std::cerr << err.what() << "\n";
    return 2;
  }
  if (cases.type != JsonVal::TArr) {
    std::cerr << "cases.json must be a JSON list\n";
    return 2;
  }

  std::vector<JsonVal> failed;
  int64_t passed = 0;
  for (const JsonVal& row : cases.arr) {
    std::unique_ptr<Harness> obj(new_target());
    std::string case_id = row.get("id").as_str();
    const JsonVal& calls = row.get("calls");
    bool ok = true;
    for (size_t i = 0; i < calls.arr.size(); i++) {
      const JsonVal& call = calls.arr[i];
      std::string method_snake = call.get("m").as_str();
      std::string method = to_camel(method_snake);
      const JsonVal& expected = call.get("e");
      JsonVal actual;
      try {
        actual = obj->call(method, call.get("a").arr);
      } catch (const std::exception& err) {
        failed.push_back(fail_row(
            case_id,
            static_cast<int64_t>(i),
            method_snake,
            expected,
            JsonVal::from_str(std::string("exc:") + err.what())));
        ok = false;
        break;
      }
      if (stringify(actual) != stringify(expected)) {
        failed.push_back(
            fail_row(case_id, static_cast<int64_t>(i), method_snake, expected, actual));
        ok = false;
        break;
      }
    }
    if (ok) {
      passed += 1;
    }
  }

  JsonVal report;
  report.type = JsonVal::TObj;
  report.obj.emplace_back("passed", JsonVal::from_int(passed));
  JsonVal failed_arr = JsonVal::from_arr(std::move(failed));
  report.obj.emplace_back("failed", failed_arr);
  std::cout << stringify(report) << "\n";
  return failed_arr.arr.empty() ? 0 : 1;
}
