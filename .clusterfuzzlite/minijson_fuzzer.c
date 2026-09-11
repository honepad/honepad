#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "minijson.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size > 65536) {
    return 0;
  }
  char *text = malloc(size + 1);
  if (text == NULL) {
    return 0;
  }
  if (size > 0) {
    memcpy(text, data, size);
  }
  text[size] = '\0';
  char err[128];
  JsonVal *val = json_parse(text, err, sizeof(err));
  json_free(val);
  free(text);
  return 0;
}
