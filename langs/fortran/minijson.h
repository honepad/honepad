#ifndef HONEPAD_MINIJSON_H
#define HONEPAD_MINIJSON_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum {
  JSON_NULL,
  JSON_BOOL,
  JSON_INT,
  JSON_DOUBLE,
  JSON_STR,
  JSON_ARR,
  JSON_OBJ
} JsonType;

typedef struct JsonVal JsonVal;

typedef struct {
  char *key;
  JsonVal *val;
} JsonPair;

struct JsonVal {
  JsonType type;
  bool b;
  int64_t i;
  double d;
  char *s;
  JsonVal **arr;
  size_t arr_len;
  size_t arr_cap;
  JsonPair *obj;
  size_t obj_len;
  size_t obj_cap;
};

JsonVal *json_null(void);
JsonVal *json_bool(bool value);
JsonVal *json_int(int64_t value);
JsonVal *json_str(const char *value);
JsonVal *json_arr(void);
JsonVal *json_obj(void);
void json_arr_push(JsonVal *arr, JsonVal *item);
void json_obj_put(JsonVal *obj, const char *key, JsonVal *val);
const JsonVal *json_obj_get(const JsonVal *obj, const char *key);
JsonVal *json_clone(const JsonVal *value);
char *json_stringify(const JsonVal *value);
JsonVal *json_parse(const char *text, char *err, size_t err_len);
void json_free(JsonVal *value);

#endif
