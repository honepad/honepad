#ifndef HONEPAD_HARNESS_H
#define HONEPAD_HARNESS_H

#include "minijson.h"

#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct HonepadTarget HonepadTarget;

struct HonepadTarget {
  JsonVal *(*call)(HonepadTarget *self, const char *method, const JsonVal *args);
  void (*free_fn)(HonepadTarget *self);
};

HonepadTarget *new_target(void);

extern jmp_buf honepad_jmp;
extern char honepad_err[512];

#define HP_GROW(ptr, len, cap, T)          \
  do {                                     \
    if ((len) >= (cap)) {                  \
      size_t _n = (cap) ? (cap) * 2 : 8;   \
      T *_p = realloc((ptr), _n * sizeof(T)); \
      if (_p == NULL) {                    \
        honepad_throw("oom");              \
      }                                    \
      (ptr) = _p;                          \
      (cap) = _n;                          \
    }                                      \
  } while (0)

static inline void honepad_throw(const char *msg) {
  snprintf(honepad_err, sizeof(honepad_err), "%s", msg);
  longjmp(honepad_jmp, 1);
}

static inline char *hp_strdup(const char *text) {
  size_t n = strlen(text) + 1;
  char *out = malloc(n);
  if (out == NULL) {
    honepad_throw("oom");
  }
  memcpy(out, text, n);
  return out;
}

static inline int64_t arg_i64(const JsonVal *args, size_t index) {
  if (args == NULL || args->type != JSON_ARR || index >= args->arr_len) {
    honepad_throw("missing arg");
  }
  const JsonVal *value = args->arr[index];
  if (value->type == JSON_INT) {
    return value->i;
  }
  if (value->type == JSON_DOUBLE) {
    int64_t truncated = (int64_t)value->d;
    if ((double)truncated == value->d) {
      return truncated;
    }
  }
  honepad_throw("json value is not i64");
  return 0;
}

static inline const char *arg_str(const JsonVal *args, size_t index) {
  if (args == NULL || args->type != JSON_ARR || index >= args->arr_len) {
    honepad_throw("missing arg");
  }
  const JsonVal *value = args->arr[index];
  if (value->type != JSON_STR || value->s == NULL) {
    honepad_throw("json value is not string");
  }
  return value->s;
}

static inline JsonVal *opt_i64(int present, int64_t value) {
  if (!present) {
    return json_null();
  }
  return json_int(value);
}

static inline JsonVal *opt_str(const char *value) {
  if (value == NULL) {
    return json_null();
  }
  return json_str(value);
}

#endif
