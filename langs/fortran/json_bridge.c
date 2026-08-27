#include "minijson.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *hp_read_file(const char *path) {
  FILE *in = fopen(path, "rb");
  if (in == NULL) {
    return NULL;
  }
  if (fseek(in, 0, SEEK_END) != 0) {
    fclose(in);
    return NULL;
  }
  long n = ftell(in);
  if (n < 0) {
    fclose(in);
    return NULL;
  }
  if (fseek(in, 0, SEEK_SET) != 0) {
    fclose(in);
    return NULL;
  }
  char *buf = malloc((size_t)n + 1);
  if (buf == NULL) {
    fclose(in);
    return NULL;
  }
  size_t got = fread(buf, 1, (size_t)n, in);
  fclose(in);
  buf[got] = '\0';
  return buf;
}

size_t hp_strlen(const char *text) { return text == NULL ? 0 : strlen(text); }

void hp_free_cstr(char *text) { free(text); }

JsonVal *hp_parse(const char *text, char *err, int err_len) {
  size_t n = err_len > 0 ? (size_t)err_len : 0;
  return json_parse(text, err, n);
}

int hp_is_null(const JsonVal *value) { return value == NULL || value->type == JSON_NULL; }

int hp_is_arr(const JsonVal *value) { return value != NULL && value->type == JSON_ARR; }

int hp_is_obj(const JsonVal *value) { return value != NULL && value->type == JSON_OBJ; }

int hp_is_str(const JsonVal *value) { return value != NULL && value->type == JSON_STR; }

int64_t hp_arr_len(const JsonVal *value) {
  if (value == NULL || value->type != JSON_ARR) {
    return 0;
  }
  return (int64_t)value->arr_len;
}

JsonVal *hp_arr_at(const JsonVal *value, int64_t index) {
  if (value == NULL || value->type != JSON_ARR || index < 0 || (size_t)index >= value->arr_len) {
    return NULL;
  }
  return value->arr[index];
}

JsonVal *hp_obj_get(const JsonVal *value, const char *key) {
  return (JsonVal *)json_obj_get(value, key);
}

const char *hp_as_str(const JsonVal *value) {
  if (value == NULL || value->type != JSON_STR || value->s == NULL) {
    return "";
  }
  return value->s;
}

int64_t hp_as_i64(const JsonVal *value) {
  if (value == NULL) {
    return 0;
  }
  if (value->type == JSON_INT) {
    return value->i;
  }
  if (value->type == JSON_DOUBLE) {
    int64_t truncated = (int64_t)value->d;
    if ((double)truncated == value->d) {
      return truncated;
    }
  }
  return 0;
}

JsonVal *hp_null(void) { return json_null(); }

JsonVal *hp_bool(int value) { return json_bool(value != 0); }

JsonVal *hp_int(int64_t value) { return json_int(value); }

JsonVal *hp_str(const char *value) { return json_str(value == NULL ? "" : value); }

JsonVal *hp_arr(void) { return json_arr(); }

void hp_arr_push(JsonVal *arr, JsonVal *item) { json_arr_push(arr, item); }

JsonVal *hp_obj(void) { return json_obj(); }

void hp_obj_put(JsonVal *obj, const char *key, JsonVal *val) { json_obj_put(obj, key, val); }

JsonVal *hp_clone(const JsonVal *value) { return json_clone(value); }

char *hp_stringify(const JsonVal *value) { return json_stringify(value); }

void hp_free(JsonVal *value) { json_free(value); }

int64_t hp_arg_i64(const JsonVal *args, int64_t index) { return hp_as_i64(hp_arr_at(args, index)); }

const char *hp_arg_str(const JsonVal *args, int64_t index) { return hp_as_str(hp_arr_at(args, index)); }
