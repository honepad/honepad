#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *key;
  int64_t limit;
  int64_t window;
  int64_t window_id;
  int has_window;
  int64_t used;
} KeyState;

typedef struct {
  HonepadTarget base;
  KeyState *keys;
  size_t key_len;
  size_t key_cap;
} Simulation;

static KeyState *find_key(Simulation *sim, const char *key) {
  for (size_t i = 0; i < sim->key_len; i++) {
    if (strcmp(sim->keys[i].key, key) == 0) {
      return &sim->keys[i];
    }
  }
  return NULL;
}

static KeyState *state(Simulation *sim, const char *key) {
  KeyState *item = find_key(sim, key);
  if (item != NULL) {
    return item;
  }
  HP_GROW(sim->keys, sim->key_len, sim->key_cap, KeyState);
  item = &sim->keys[sim->key_len];
  item->key = hp_strdup(key);
  item->limit = 3;
  item->window = 10;
  item->window_id = 0;
  item->has_window = 0;
  item->used = 0;
  sim->key_len++;
  return item;
}

static int64_t used_at(KeyState *item, int64_t timestamp, int persist) {
  int64_t window_id = timestamp / item->window;
  if (!item->has_window || window_id != item->window_id) {
    if (persist) {
      item->window_id = window_id;
      item->has_window = 1;
      item->used = 0;
    }
    return 0;
  }
  return item->used;
}

static char *fmt_i64(int64_t n) {
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)n);
  return hp_strdup(buf);
}

static char *allow_weighted(Simulation *sim, const char *key, int64_t cost, int64_t timestamp) {
  if (cost <= 0) {
    return hp_strdup("invalid_request");
  }
  KeyState *item = state(sim, key);
  used_at(item, timestamp, 1);
  if (item->used + cost > item->limit) {
    return hp_strdup("false");
  }
  item->used += cost;
  return hp_strdup("true");
}

static char *allow(Simulation *sim, const char *key, int64_t timestamp) {
  return allow_weighted(sim, key, 1, timestamp);
}

static char *configure(Simulation *sim, const char *key, int64_t limit, int64_t window) {
  if (limit <= 0 || window <= 0) {
    return hp_strdup("invalid_request");
  }
  KeyState *item = state(sim, key);
  item->limit = limit;
  item->window = window;
  item->has_window = 0;
  item->used = 0;
  return hp_strdup("true");
}

static char *remaining(Simulation *sim, const char *key, int64_t timestamp) {
  KeyState *item = state(sim, key);
  int64_t used = used_at(item, timestamp, 0);
  return fmt_i64(item->limit - used);
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "allow") == 0) {
    text = allow(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "configure") == 0) {
    text = configure(sim, arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2));
  } else if (strcmp(method, "remaining") == 0) {
    text = remaining(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "allow_weighted") == 0) {
    text = allow_weighted(sim, arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2));
  } else {
    char buf[128];
    snprintf(buf, sizeof(buf), "missing method %s", method);
    honepad_throw(buf);
  }
  JsonVal *out = json_str(text);
  free(text);
  return out;
}

static void simulation_free(HonepadTarget *self) {
  Simulation *sim = (Simulation *)self;
  for (size_t i = 0; i < sim->key_len; i++) {
    free(sim->keys[i].key);
  }
  free(sim->keys);
  free(sim);
}

static HonepadTarget *Simulation_new(void) {
  Simulation *sim = calloc(1, sizeof(*sim));
  if (sim == NULL) {
    fprintf(stderr, "oom\n");
    exit(2);
  }
  sim->base.call = simulation_call;
  sim->base.free_fn = simulation_free;
  return &sim->base;
}

#endif
