#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <string>
#include <utility>
#include <vector>

class Simulation : public Harness {
  std::string buf;
  int64_t pos = 0;
  std::vector<std::pair<std::string, int64_t>> undo_stack;
  std::vector<std::pair<std::string, int64_t>> redo_stack;
  int64_t sel_start = -1;
  int64_t sel_end = -1;
  std::string clip;

  void push() {
    undo_stack.emplace_back(buf, pos);
    redo_stack.clear();
    sel_start = -1;
    sel_end = -1;
  }

  std::string insert(int64_t at, const std::string& text) {
    if (at < 0 || at > static_cast<int64_t>(buf.size())) {
      return "invalid_request";
    }
    push();
    buf.insert(static_cast<size_t>(at), text);
    return std::to_string(buf.size());
  }

  std::string erase(int64_t at, int64_t n) {
    if (n <= 0 || at < 0 || at + n > static_cast<int64_t>(buf.size())) {
      return "invalid_request";
    }
    push();
    std::string deleted = buf.substr(static_cast<size_t>(at), static_cast<size_t>(n));
    buf.erase(static_cast<size_t>(at), static_cast<size_t>(n));
    if (pos > static_cast<int64_t>(buf.size())) {
      pos = static_cast<int64_t>(buf.size());
    }
    return deleted;
  }

  std::string get_text() const { return buf; }

  std::string length() const { return std::to_string(buf.size()); }

  std::string move(int64_t at) {
    if (at < 0 || at > static_cast<int64_t>(buf.size())) {
      return "invalid_request";
    }
    pos = at;
    return "true";
  }

  std::string type_text(const std::string& text) {
    push();
    int64_t at = pos;
    buf.insert(static_cast<size_t>(at), text);
    pos = at + static_cast<int64_t>(text.size());
    return std::to_string(buf.size());
  }

  std::string cursor() const { return std::to_string(pos); }

  std::string undo() {
    if (undo_stack.empty()) {
      return "false";
    }
    redo_stack.emplace_back(buf, pos);
    buf = undo_stack.back().first;
    pos = undo_stack.back().second;
    undo_stack.pop_back();
    sel_start = -1;
    sel_end = -1;
    return "true";
  }

  std::string redo() {
    if (redo_stack.empty()) {
      return "false";
    }
    undo_stack.emplace_back(buf, pos);
    buf = redo_stack.back().first;
    pos = redo_stack.back().second;
    redo_stack.pop_back();
    sel_start = -1;
    sel_end = -1;
    return "true";
  }

  std::string select(int64_t start, int64_t end) {
    if (start < 0 || end < 0 || start > end || end > static_cast<int64_t>(buf.size())) {
      return "invalid_request";
    }
    sel_start = start;
    sel_end = end;
    return "true";
  }

  std::string cut() {
    if (sel_start < 0 || sel_start == sel_end) {
      return "invalid_request";
    }
    std::string text =
        buf.substr(static_cast<size_t>(sel_start), static_cast<size_t>(sel_end - sel_start));
    buf.erase(static_cast<size_t>(sel_start), static_cast<size_t>(sel_end - sel_start));
    clip = text;
    pos = sel_start;
    sel_start = -1;
    sel_end = -1;
    return text;
  }

  std::string copy_sel() {
    if (sel_start < 0 || sel_start == sel_end) {
      return "invalid_request";
    }
    clip = buf.substr(static_cast<size_t>(sel_start), static_cast<size_t>(sel_end - sel_start));
    return clip;
  }

  std::string paste() {
    if (clip.empty()) {
      return "invalid_request";
    }
    int64_t at = pos;
    buf.insert(static_cast<size_t>(at), clip);
    pos = at + static_cast<int64_t>(clip.size());
    return std::to_string(buf.size());
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "insert") {
      text = insert(arg_i64(args, 0), arg_str(args, 1));
    } else if (method == "erase") {
      text = erase(arg_i64(args, 0), arg_i64(args, 1));
    } else if (method == "getText") {
      text = get_text();
    } else if (method == "length") {
      text = length();
    } else if (method == "move") {
      text = move(arg_i64(args, 0));
    } else if (method == "typeText") {
      text = type_text(arg_str(args, 0));
    } else if (method == "cursor") {
      text = cursor();
    } else if (method == "undo") {
      text = undo();
    } else if (method == "redo") {
      text = redo();
    } else if (method == "select") {
      text = select(arg_i64(args, 0), arg_i64(args, 1));
    } else if (method == "cut") {
      text = cut();
    } else if (method == "copySel") {
      text = copy_sel();
    } else if (method == "paste") {
      text = paste();
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
