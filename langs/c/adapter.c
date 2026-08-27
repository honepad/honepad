#include "harness.h"
#include "minijson.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

jmp_buf honepad_jmp;
char honepad_err[512];

static char *read_file(const char *path) {
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

static JsonVal *fail_row(
    const char *case_id,
    int64_t index,
    const char *method,
    const JsonVal *expected,
    JsonVal *actual) {
  JsonVal *row = json_obj();
  json_obj_put(row, "case", json_str(case_id));
  json_obj_put(row, "index", json_int(index));
  json_obj_put(row, "method", json_str(method));
  json_obj_put(row, "expected", json_clone(expected));
  json_obj_put(row, "actual", actual);
  return row;
}

static const JsonVal *need(const JsonVal *obj, const char *key) {
  const JsonVal *found = json_obj_get(obj, key);
  if (found == NULL) {
    fprintf(stderr, "missing json key %s\n", key);
    exit(2);
  }
  return found;
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: adapter cases.json\n");
    return 2;
  }
  char *raw = read_file(argv[1]);
  if (raw == NULL) {
    fprintf(stderr, "cannot read %s\n", argv[1]);
    return 2;
  }
  char err[256];
  JsonVal *cases = json_parse(raw, err, sizeof(err));
  free(raw);
  if (cases == NULL) {
    fprintf(stderr, "%s\n", err);
    return 2;
  }
  if (cases->type != JSON_ARR) {
    fprintf(stderr, "cases.json must be a JSON list\n");
    json_free(cases);
    return 2;
  }

  JsonVal *failed = json_arr();
  int64_t passed = 0;
  for (size_t c = 0; c < cases->arr_len; c++) {
    const JsonVal *row = cases->arr[c];
    HonepadTarget *obj = new_target();
    const JsonVal *id_v = need(row, "id");
    const JsonVal *calls = need(row, "calls");
    if (id_v->type != JSON_STR || calls->type != JSON_ARR) {
      fprintf(stderr, "bad case row\n");
      return 2;
    }
    const char *case_id = id_v->s;
    int ok = 1;
    for (size_t i = 0; i < calls->arr_len; i++) {
      const JsonVal *call = calls->arr[i];
      const JsonVal *method_v = need(call, "m");
      const JsonVal *expected = need(call, "e");
      const JsonVal *args = need(call, "a");
      if (method_v->type != JSON_STR) {
        fprintf(stderr, "bad method\n");
        return 2;
      }
      const char *method = method_v->s;
      JsonVal *actual = NULL;
      if (setjmp(honepad_jmp) != 0) {
        char buf[600];
        snprintf(buf, sizeof(buf), "exc:%s", honepad_err);
        json_arr_push(failed, fail_row(case_id, (int64_t)i, method, expected, json_str(buf)));
        ok = 0;
        break;
      }
      actual = obj->call(obj, method, args);
      char *got = json_stringify(actual);
      char *want = json_stringify(expected);
      int match = strcmp(got, want) == 0;
      free(got);
      free(want);
      if (!match) {
        json_arr_push(failed, fail_row(case_id, (int64_t)i, method, expected, actual));
        ok = 0;
        break;
      }
      json_free(actual);
    }
    obj->free_fn(obj);
    if (ok) {
      passed += 1;
    }
  }

  JsonVal *report = json_obj();
  json_obj_put(report, "passed", json_int(passed));
  json_obj_put(report, "failed", failed);
  char *out = json_stringify(report);
  printf("%s\n", out);
  int rc = failed->arr_len == 0 ? 0 : 1;
  free(out);
  json_free(report);
  json_free(cases);
  return rc;
}
