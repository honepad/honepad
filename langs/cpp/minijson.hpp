#ifndef HONEPAD_MINIJSON_HPP
#define HONEPAD_MINIJSON_HPP

#include <cmath>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

struct JsonVal {
  enum Type { TNull, TBool, TInt, TDouble, TStr, TArr, TObj };

  Type type = TNull;
  bool b = false;
  int64_t i = 0;
  double d = 0.0;
  std::string s;
  std::vector<JsonVal> arr;
  std::vector<std::pair<std::string, JsonVal>> obj;

  static JsonVal nullv() { return JsonVal(); }

  static JsonVal from_bool(bool value) {
    JsonVal out;
    out.type = TBool;
    out.b = value;
    return out;
  }

  static JsonVal from_int(int64_t value) {
    JsonVal out;
    out.type = TInt;
    out.i = value;
    return out;
  }

  static JsonVal from_str(std::string value) {
    JsonVal out;
    out.type = TStr;
    out.s = std::move(value);
    return out;
  }

  static JsonVal from_arr(std::vector<JsonVal> value) {
    JsonVal out;
    out.type = TArr;
    out.arr = std::move(value);
    return out;
  }

  bool is_null() const { return type == TNull; }

  int64_t as_i64() const {
    if (type == TInt) {
      return i;
    }
    if (type == TDouble) {
      auto truncated = static_cast<int64_t>(d);
      if (static_cast<double>(truncated) == d) {
        return truncated;
      }
    }
    throw std::runtime_error("json value is not i64");
  }

  std::string as_str() const {
    if (type != TStr) {
      throw std::runtime_error("json value is not string");
    }
    return s;
  }

  const JsonVal* find(const std::string& key) const {
    for (const auto& item : obj) {
      if (item.first == key) {
        return &item.second;
      }
    }
    return nullptr;
  }

  const JsonVal& get(const std::string& key) const {
    const JsonVal* found = find(key);
    if (found == nullptr) {
      throw std::runtime_error("missing json key " + key);
    }
    return *found;
  }
};

inline void json_escape(std::string& out, const std::string& text) {
  for (unsigned char ch : text) {
    switch (ch) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\b':
        out += "\\b";
        break;
      case '\f':
        out += "\\f";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        if (ch < 0x20) {
          const char* hex = "0123456789abcdef";
          out += "\\u00";
          out += hex[ch >> 4];
          out += hex[ch & 0x0f];
        } else {
          out += static_cast<char>(ch);
        }
    }
  }
}

inline void stringify_into(std::string& out, const JsonVal& value) {
  switch (value.type) {
    case JsonVal::TNull:
      out += "null";
      return;
    case JsonVal::TBool:
      out += value.b ? "true" : "false";
      return;
    case JsonVal::TInt:
      out += std::to_string(value.i);
      return;
    case JsonVal::TDouble:
      if (!std::isinf(value.d) && value.d == static_cast<double>(static_cast<int64_t>(value.d))) {
        out += std::to_string(static_cast<int64_t>(value.d));
      } else {
        out += std::to_string(value.d);
      }
      return;
    case JsonVal::TStr:
      out += '"';
      json_escape(out, value.s);
      out += '"';
      return;
    case JsonVal::TArr:
      out += '[';
      for (size_t i = 0; i < value.arr.size(); i++) {
        if (i > 0) {
          out += ',';
        }
        stringify_into(out, value.arr[i]);
      }
      out += ']';
      return;
    case JsonVal::TObj:
      out += '{';
      for (size_t i = 0; i < value.obj.size(); i++) {
        if (i > 0) {
          out += ',';
        }
        out += '"';
        json_escape(out, value.obj[i].first);
        out += "\":";
        stringify_into(out, value.obj[i].second);
      }
      out += '}';
      return;
  }
}

inline std::string stringify(const JsonVal& value) {
  std::string out;
  stringify_into(out, value);
  return out;
}

struct JsonParser {
  const std::string& text;
  size_t pos = 0;

  explicit JsonParser(const std::string& text) : text(text) {}

  bool done() const { return pos >= text.size(); }

  void skip_ws() {
    while (pos < text.size()) {
      char ch = text[pos];
      if (ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t') {
        break;
      }
      pos++;
    }
  }

  char peek() {
    skip_ws();
    if (done()) {
      throw std::runtime_error("unexpected end of json");
    }
    return text[pos];
  }

  char next() {
    skip_ws();
    if (done()) {
      throw std::runtime_error("unexpected end of json");
    }
    return text[pos++];
  }

  void expect(char wanted) {
    char ch = next();
    if (ch != wanted) {
      throw std::runtime_error(std::string("expected ") + wanted);
    }
  }

  void parse_literal(const char* lit) {
    skip_ws();
    for (size_t i = 0; lit[i] != '\0'; i++) {
      if (pos >= text.size() || text[pos] != lit[i]) {
        throw std::runtime_error(std::string("expected ") + lit);
      }
      pos++;
    }
  }

  JsonVal parse_value() {
    char ch = peek();
    if (ch == '{') {
      return parse_object();
    }
    if (ch == '[') {
      return parse_array();
    }
    if (ch == '"') {
      return JsonVal::from_str(parse_string());
    }
    if (ch == 't') {
      parse_literal("true");
      return JsonVal::from_bool(true);
    }
    if (ch == 'f') {
      parse_literal("false");
      return JsonVal::from_bool(false);
    }
    if (ch == 'n') {
      parse_literal("null");
      return JsonVal::nullv();
    }
    if (ch == '-' || (ch >= '0' && ch <= '9')) {
      return parse_number();
    }
    throw std::runtime_error("bad json");
  }

  JsonVal parse_object() {
    expect('{');
    JsonVal out;
    out.type = JsonVal::TObj;
    skip_ws();
    if (peek() == '}') {
      pos++;
      return out;
    }
    while (true) {
      std::string key = parse_string();
      expect(':');
      out.obj.emplace_back(std::move(key), parse_value());
      skip_ws();
      char ch = next();
      if (ch == '}') {
        return out;
      }
      if (ch != ',') {
        throw std::runtime_error("expected comma");
      }
    }
  }

  JsonVal parse_array() {
    expect('[');
    JsonVal out;
    out.type = JsonVal::TArr;
    skip_ws();
    if (peek() == ']') {
      pos++;
      return out;
    }
    while (true) {
      out.arr.push_back(parse_value());
      skip_ws();
      char ch = next();
      if (ch == ']') {
        return out;
      }
      if (ch != ',') {
        throw std::runtime_error("expected comma");
      }
    }
  }

  std::string parse_string() {
    expect('"');
    std::string out;
    while (pos < text.size()) {
      char ch = text[pos++];
      if (ch == '"') {
        return out;
      }
      if (ch != '\\') {
        out += ch;
        continue;
      }
      if (pos >= text.size()) {
        throw std::runtime_error("unterminated escape");
      }
      char esc = text[pos++];
      switch (esc) {
        case '"':
        case '\\':
        case '/':
          out += esc;
          break;
        case 'b':
          out += '\b';
          break;
        case 'f':
          out += '\f';
          break;
        case 'n':
          out += '\n';
          break;
        case 'r':
          out += '\r';
          break;
        case 't':
          out += '\t';
          break;
        case 'u': {
          if (pos + 4 > text.size()) {
            throw std::runtime_error("bad unicode escape");
          }
          int code = 0;
          for (int i = 0; i < 4; i++) {
            char hex = text[pos++];
            code <<= 4;
            if (hex >= '0' && hex <= '9') {
              code += hex - '0';
            } else if (hex >= 'a' && hex <= 'f') {
              code += hex - 'a' + 10;
            } else if (hex >= 'A' && hex <= 'F') {
              code += hex - 'A' + 10;
            } else {
              throw std::runtime_error("bad unicode escape");
            }
          }
          if (code < 0x80) {
            out += static_cast<char>(code);
          } else if (code < 0x800) {
            out += static_cast<char>(0xc0 | (code >> 6));
            out += static_cast<char>(0x80 | (code & 0x3f));
          } else {
            out += static_cast<char>(0xe0 | (code >> 12));
            out += static_cast<char>(0x80 | ((code >> 6) & 0x3f));
            out += static_cast<char>(0x80 | (code & 0x3f));
          }
          break;
        }
        default:
          throw std::runtime_error("bad escape");
      }
    }
    throw std::runtime_error("unterminated string");
  }

  JsonVal parse_number() {
    skip_ws();
    size_t start = pos;
    if (text[pos] == '-') {
      pos++;
    }
    while (pos < text.size() && text[pos] >= '0' && text[pos] <= '9') {
      pos++;
    }
    bool frac = false;
    if (pos < text.size() && text[pos] == '.') {
      frac = true;
      pos++;
      while (pos < text.size() && text[pos] >= '0' && text[pos] <= '9') {
        pos++;
      }
    }
    if (pos < text.size() && (text[pos] == 'e' || text[pos] == 'E')) {
      frac = true;
      pos++;
      if (pos < text.size() && (text[pos] == '+' || text[pos] == '-')) {
        pos++;
      }
      while (pos < text.size() && text[pos] >= '0' && text[pos] <= '9') {
        pos++;
      }
    }
    std::string raw = text.substr(start, pos - start);
    if (frac) {
      JsonVal out;
      out.type = JsonVal::TDouble;
      out.d = std::stod(raw);
      return out;
    }
    return JsonVal::from_int(std::stoll(raw));
  }
};

inline JsonVal parse_json(const std::string& text) {
  JsonParser parser(text);
  JsonVal value = parser.parse_value();
  parser.skip_ws();
  if (!parser.done()) {
    throw std::runtime_error("trailing json");
  }
  return value;
}

#endif
