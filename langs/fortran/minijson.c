#include "minijson.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void die_oom(void) {
  fprintf(stderr, "oom\n");
  exit(2);
}

static char *xstrdup(const char *text) {
  size_t n = strlen(text) + 1;
  char *out = malloc(n);
  if (out == NULL) {
    die_oom();
  }
  memcpy(out, text, n);
  return out;
}

static JsonVal *new_val(JsonType type) {
  JsonVal *out = calloc(1, sizeof(*out));
  if (out == NULL) {
    die_oom();
  }
  out->type = type;
  return out;
}

JsonVal *json_null(void) { return new_val(JSON_NULL); }

JsonVal *json_bool(bool value) {
  JsonVal *out = new_val(JSON_BOOL);
  out->b = value;
  return out;
}

JsonVal *json_int(int64_t value) {
  JsonVal *out = new_val(JSON_INT);
  out->i = value;
  return out;
}

JsonVal *json_str(const char *value) {
  JsonVal *out = new_val(JSON_STR);
  out->s = xstrdup(value ? value : "");
  return out;
}

JsonVal *json_arr(void) { return new_val(JSON_ARR); }

JsonVal *json_obj(void) { return new_val(JSON_OBJ); }

void json_arr_push(JsonVal *arr, JsonVal *item) {
  if (arr->arr_len >= arr->arr_cap) {
    size_t cap = arr->arr_cap ? arr->arr_cap * 2 : 8;
    JsonVal **next = realloc(arr->arr, cap * sizeof(*next));
    if (next == NULL) {
      die_oom();
    }
    arr->arr = next;
    arr->arr_cap = cap;
  }
  arr->arr[arr->arr_len++] = item;
}

void json_obj_put(JsonVal *obj, const char *key, JsonVal *val) {
  if (obj->obj_len >= obj->obj_cap) {
    size_t cap = obj->obj_cap ? obj->obj_cap * 2 : 8;
    JsonPair *next = realloc(obj->obj, cap * sizeof(*next));
    if (next == NULL) {
      die_oom();
    }
    obj->obj = next;
    obj->obj_cap = cap;
  }
  obj->obj[obj->obj_len].key = xstrdup(key);
  obj->obj[obj->obj_len].val = val;
  obj->obj_len++;
}

const JsonVal *json_obj_get(const JsonVal *obj, const char *key) {
  if (obj == NULL || obj->type != JSON_OBJ) {
    return NULL;
  }
  for (size_t i = 0; i < obj->obj_len; i++) {
    if (strcmp(obj->obj[i].key, key) == 0) {
      return obj->obj[i].val;
    }
  }
  return NULL;
}

JsonVal *json_clone(const JsonVal *value) {
  if (value == NULL) {
    return json_null();
  }
  switch (value->type) {
    case JSON_NULL:
      return json_null();
    case JSON_BOOL:
      return json_bool(value->b);
    case JSON_INT:
      return json_int(value->i);
    case JSON_DOUBLE: {
      JsonVal *out = new_val(JSON_DOUBLE);
      out->d = value->d;
      return out;
    }
    case JSON_STR:
      return json_str(value->s);
    case JSON_ARR: {
      JsonVal *out = json_arr();
      for (size_t i = 0; i < value->arr_len; i++) {
        json_arr_push(out, json_clone(value->arr[i]));
      }
      return out;
    }
    case JSON_OBJ: {
      JsonVal *out = json_obj();
      for (size_t i = 0; i < value->obj_len; i++) {
        json_obj_put(out, value->obj[i].key, json_clone(value->obj[i].val));
      }
      return out;
    }
  }
  return json_null();
}

void json_free(JsonVal *value) {
  if (value == NULL) {
    return;
  }
  free(value->s);
  for (size_t i = 0; i < value->arr_len; i++) {
    json_free(value->arr[i]);
  }
  free(value->arr);
  for (size_t i = 0; i < value->obj_len; i++) {
    free(value->obj[i].key);
    json_free(value->obj[i].val);
  }
  free(value->obj);
  free(value);
}

typedef struct {
  char *data;
  size_t len;
  size_t cap;
} Buf;

static void buf_grow(Buf *buf, size_t need) {
  if (buf->len + need + 1 <= buf->cap) {
    return;
  }
  size_t cap = buf->cap ? buf->cap : 64;
  while (buf->len + need + 1 > cap) {
    cap *= 2;
  }
  char *data = realloc(buf->data, cap);
  if (data == NULL) {
    die_oom();
  }
  buf->data = data;
  buf->cap = cap;
}

static void buf_putc(Buf *buf, char ch) {
  buf_grow(buf, 1);
  buf->data[buf->len++] = ch;
  buf->data[buf->len] = '\0';
}

static void buf_puts(Buf *buf, const char *text) {
  size_t n = strlen(text);
  buf_grow(buf, n);
  memcpy(buf->data + buf->len, text, n);
  buf->len += n;
  buf->data[buf->len] = '\0';
}

static void escape_into(Buf *buf, const char *text) {
  static const char *hex = "0123456789abcdef";
  for (const unsigned char *p = (const unsigned char *)text; *p; p++) {
    unsigned char ch = *p;
    switch (ch) {
      case '"':
        buf_puts(buf, "\\\"");
        break;
      case '\\':
        buf_puts(buf, "\\\\");
        break;
      case '\b':
        buf_puts(buf, "\\b");
        break;
      case '\f':
        buf_puts(buf, "\\f");
        break;
      case '\n':
        buf_puts(buf, "\\n");
        break;
      case '\r':
        buf_puts(buf, "\\r");
        break;
      case '\t':
        buf_puts(buf, "\\t");
        break;
      default:
        if (ch < 0x20) {
          char tmp[7] = {'\\', 'u', '0', '0', hex[ch >> 4], hex[ch & 0x0f], 0};
          buf_puts(buf, tmp);
        } else {
          buf_putc(buf, (char)ch);
        }
    }
  }
}

static void stringify_into(Buf *buf, const JsonVal *value) {
  char tmp[64];
  switch (value->type) {
    case JSON_NULL:
      buf_puts(buf, "null");
      return;
    case JSON_BOOL:
      buf_puts(buf, value->b ? "true" : "false");
      return;
    case JSON_INT:
      snprintf(tmp, sizeof(tmp), "%lld", (long long)value->i);
      buf_puts(buf, tmp);
      return;
    case JSON_DOUBLE: {
      int64_t truncated = (int64_t)value->d;
      if (value->d == (double)truncated) {
        snprintf(tmp, sizeof(tmp), "%lld", (long long)truncated);
      } else {
        snprintf(tmp, sizeof(tmp), "%.17g", value->d);
      }
      buf_puts(buf, tmp);
      return;
    }
    case JSON_STR:
      buf_putc(buf, '"');
      escape_into(buf, value->s ? value->s : "");
      buf_putc(buf, '"');
      return;
    case JSON_ARR:
      buf_putc(buf, '[');
      for (size_t i = 0; i < value->arr_len; i++) {
        if (i > 0) {
          buf_putc(buf, ',');
        }
        stringify_into(buf, value->arr[i]);
      }
      buf_putc(buf, ']');
      return;
    case JSON_OBJ:
      buf_putc(buf, '{');
      for (size_t i = 0; i < value->obj_len; i++) {
        if (i > 0) {
          buf_putc(buf, ',');
        }
        buf_putc(buf, '"');
        escape_into(buf, value->obj[i].key);
        buf_puts(buf, "\":");
        stringify_into(buf, value->obj[i].val);
      }
      buf_putc(buf, '}');
      return;
  }
}

char *json_stringify(const JsonVal *value) {
  Buf buf = {0};
  stringify_into(&buf, value);
  if (buf.data == NULL) {
    return xstrdup("");
  }
  return buf.data;
}

typedef struct {
  const char *text;
  size_t pos;
  char err[256];
} Parser;

static void set_err(Parser *p, const char *msg) {
  snprintf(p->err, sizeof(p->err), "%s", msg);
}

static int done(const Parser *p) { return p->text[p->pos] == '\0'; }

static void skip_ws(Parser *p) {
  while (p->text[p->pos] == ' ' || p->text[p->pos] == '\n' || p->text[p->pos] == '\r' ||
         p->text[p->pos] == '\t') {
    p->pos++;
  }
}

static char peek(Parser *p) {
  skip_ws(p);
  return p->text[p->pos];
}

static char nextc(Parser *p) {
  skip_ws(p);
  if (done(p)) {
    set_err(p, "unexpected end of json");
    return 0;
  }
  return p->text[p->pos++];
}

static int expect(Parser *p, char wanted) {
  char ch = nextc(p);
  if (ch != wanted) {
    set_err(p, "expected token");
    return 0;
  }
  return 1;
}

static int parse_literal(Parser *p, const char *lit) {
  skip_ws(p);
  for (size_t i = 0; lit[i] != '\0'; i++) {
    if (p->text[p->pos] != lit[i]) {
      set_err(p, "expected literal");
      return 0;
    }
    p->pos++;
  }
  return 1;
}

static JsonVal *parse_value(Parser *p);

static char *parse_string(Parser *p) {
  if (!expect(p, '"')) {
    return NULL;
  }
  Buf buf = {0};
  while (p->text[p->pos] != '\0') {
    char ch = p->text[p->pos++];
    if (ch == '"') {
      if (buf.data == NULL) {
        return xstrdup("");
      }
      return buf.data;
    }
    if (ch != '\\') {
      buf_putc(&buf, ch);
      continue;
    }
    if (p->text[p->pos] == '\0') {
      set_err(p, "unterminated escape");
      free(buf.data);
      return NULL;
    }
    char esc = p->text[p->pos++];
    switch (esc) {
      case '"':
      case '\\':
      case '/':
        buf_putc(&buf, esc);
        break;
      case 'b':
        buf_putc(&buf, '\b');
        break;
      case 'f':
        buf_putc(&buf, '\f');
        break;
      case 'n':
        buf_putc(&buf, '\n');
        break;
      case 'r':
        buf_putc(&buf, '\r');
        break;
      case 't':
        buf_putc(&buf, '\t');
        break;
      case 'u': {
        int code = 0;
        for (int i = 0; i < 4; i++) {
          char hex = p->text[p->pos++];
          code <<= 4;
          if (hex >= '0' && hex <= '9') {
            code += hex - '0';
          } else if (hex >= 'a' && hex <= 'f') {
            code += hex - 'a' + 10;
          } else if (hex >= 'A' && hex <= 'F') {
            code += hex - 'A' + 10;
          } else {
            set_err(p, "bad unicode escape");
            free(buf.data);
            return NULL;
          }
        }
        if (code < 0x80) {
          buf_putc(&buf, (char)code);
        } else if (code < 0x800) {
          buf_putc(&buf, (char)(0xc0 | (code >> 6)));
          buf_putc(&buf, (char)(0x80 | (code & 0x3f)));
        } else {
          buf_putc(&buf, (char)(0xe0 | (code >> 12)));
          buf_putc(&buf, (char)(0x80 | ((code >> 6) & 0x3f)));
          buf_putc(&buf, (char)(0x80 | (code & 0x3f)));
        }
        break;
      }
      default:
        set_err(p, "bad escape");
        free(buf.data);
        return NULL;
    }
  }
  set_err(p, "unterminated string");
  free(buf.data);
  return NULL;
}

static JsonVal *parse_number(Parser *p) {
  skip_ws(p);
  size_t start = p->pos;
  if (p->text[p->pos] == '-') {
    p->pos++;
  }
  while (p->text[p->pos] >= '0' && p->text[p->pos] <= '9') {
    p->pos++;
  }
  int frac = 0;
  if (p->text[p->pos] == '.') {
    frac = 1;
    p->pos++;
    while (p->text[p->pos] >= '0' && p->text[p->pos] <= '9') {
      p->pos++;
    }
  }
  if (p->text[p->pos] == 'e' || p->text[p->pos] == 'E') {
    frac = 1;
    p->pos++;
    if (p->text[p->pos] == '+' || p->text[p->pos] == '-') {
      p->pos++;
    }
    while (p->text[p->pos] >= '0' && p->text[p->pos] <= '9') {
      p->pos++;
    }
  }
  size_t n = p->pos - start;
  char *raw = malloc(n + 1);
  if (raw == NULL) {
    die_oom();
  }
  memcpy(raw, p->text + start, n);
  raw[n] = '\0';
  JsonVal *out;
  if (frac) {
    out = new_val(JSON_DOUBLE);
    out->d = strtod(raw, NULL);
  } else {
    out = json_int(strtoll(raw, NULL, 10));
  }
  free(raw);
  return out;
}

static JsonVal *parse_object(Parser *p) {
  if (!expect(p, '{')) {
    return NULL;
  }
  JsonVal *out = json_obj();
  skip_ws(p);
  if (peek(p) == '}') {
    p->pos++;
    return out;
  }
  while (1) {
    char *key = parse_string(p);
    if (key == NULL) {
      json_free(out);
      return NULL;
    }
    if (!expect(p, ':')) {
      free(key);
      json_free(out);
      return NULL;
    }
    JsonVal *val = parse_value(p);
    if (val == NULL) {
      free(key);
      json_free(out);
      return NULL;
    }
    json_obj_put(out, key, val);
    free(key);
    skip_ws(p);
    char ch = nextc(p);
    if (ch == '}') {
      return out;
    }
    if (ch != ',') {
      set_err(p, "expected comma");
      json_free(out);
      return NULL;
    }
  }
}

static JsonVal *parse_array(Parser *p) {
  if (!expect(p, '[')) {
    return NULL;
  }
  JsonVal *out = json_arr();
  skip_ws(p);
  if (peek(p) == ']') {
    p->pos++;
    return out;
  }
  while (1) {
    JsonVal *val = parse_value(p);
    if (val == NULL) {
      json_free(out);
      return NULL;
    }
    json_arr_push(out, val);
    skip_ws(p);
    char ch = nextc(p);
    if (ch == ']') {
      return out;
    }
    if (ch != ',') {
      set_err(p, "expected comma");
      json_free(out);
      return NULL;
    }
  }
}

static JsonVal *parse_value(Parser *p) {
  char ch = peek(p);
  if (ch == '{') {
    return parse_object(p);
  }
  if (ch == '[') {
    return parse_array(p);
  }
  if (ch == '"') {
    char *s = parse_string(p);
    if (s == NULL) {
      return NULL;
    }
    JsonVal *out = json_str(s);
    free(s);
    return out;
  }
  if (ch == 't') {
    if (!parse_literal(p, "true")) {
      return NULL;
    }
    return json_bool(true);
  }
  if (ch == 'f') {
    if (!parse_literal(p, "false")) {
      return NULL;
    }
    return json_bool(false);
  }
  if (ch == 'n') {
    if (!parse_literal(p, "null")) {
      return NULL;
    }
    return json_null();
  }
  if (ch == '-' || (ch >= '0' && ch <= '9')) {
    return parse_number(p);
  }
  set_err(p, "bad json");
  return NULL;
}

JsonVal *json_parse(const char *text, char *err, size_t err_len) {
  Parser p = {0};
  p.text = text ? text : "";
  JsonVal *value = parse_value(&p);
  if (value == NULL) {
    if (err != NULL && err_len > 0) {
      snprintf(err, err_len, "%s", p.err[0] ? p.err : "bad json");
    }
    return NULL;
  }
  skip_ws(&p);
  if (!done(&p)) {
    json_free(value);
    if (err != NULL && err_len > 0) {
      snprintf(err, err_len, "trailing json");
    }
    return NULL;
  }
  return value;
}
