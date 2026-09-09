#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *backend_id;
  int health;
  int64_t weight;
  int64_t inflight;
} Backend;

typedef struct {
  char *client_id;
  char *backend_id;
} Sticky;

typedef struct {
  HonepadTarget base;
  Backend *backends;
  size_t backend_len;
  size_t backend_cap;
  Sticky *sticky;
  size_t sticky_len;
  size_t sticky_cap;
  int64_t cursor;
  int use_least;
} Simulation;

static Backend *find_backend(Simulation *sim, const char *backend_id) {
  for (size_t i = 0; i < sim->backend_len; i++) {
    if (strcmp(sim->backends[i].backend_id, backend_id) == 0) {
      return &sim->backends[i];
    }
  }
  return NULL;
}

static char *add_backend(Simulation *sim, const char *backend_id) {
  if (find_backend(sim, backend_id) != NULL) {
    return hp_strdup("false");
  }
  HP_GROW(sim->backends, sim->backend_len, sim->backend_cap, Backend);
  sim->backends[sim->backend_len].backend_id = hp_strdup(backend_id);
  sim->backends[sim->backend_len].health = 1;
  sim->backends[sim->backend_len].weight = 1;
  sim->backends[sim->backend_len].inflight = 0;
  sim->backend_len++;
  return hp_strdup("true");
}

static void reset_cycle(Simulation *sim) {
  sim->cursor = 0;
  sim->use_least = 0;
  for (size_t i = 0; i < sim->backend_len; i++) {
    sim->backends[i].inflight = 0;
  }
}

static char *set_health(Simulation *sim, const char *backend_id, int64_t flag) {
  Backend *item = find_backend(sim, backend_id);
  if (item == NULL || (flag != 0 && flag != 1)) {
    return hp_strdup("invalid_request");
  }
  item->health = flag == 1;
  reset_cycle(sim);
  return hp_strdup("true");
}

static char *set_weight(Simulation *sim, const char *backend_id, int64_t weight) {
  Backend *item = find_backend(sim, backend_id);
  if (item == NULL || weight <= 0) {
    return hp_strdup("invalid_request");
  }
  item->weight = weight;
  reset_cycle(sim);
  return hp_strdup("true");
}

static Backend *pick(Simulation *sim) {
  Backend **healthy = NULL;
  size_t hlen = 0;
  size_t hcap = 0;
  for (size_t i = 0; i < sim->backend_len; i++) {
    if (sim->backends[i].health) {
      HP_GROW(healthy, hlen, hcap, Backend *);
      healthy[hlen++] = &sim->backends[i];
    }
  }
  if (hlen == 0) {
    free(healthy);
    return NULL;
  }
  Backend **pool = healthy;
  size_t plen = hlen;
  Backend **least_pool = NULL;
  size_t llen = 0;
  size_t lcap = 0;
  if (sim->use_least) {
    int64_t least = healthy[0]->inflight;
    for (size_t i = 1; i < hlen; i++) {
      if (healthy[i]->inflight < least) {
        least = healthy[i]->inflight;
      }
    }
    for (size_t i = 0; i < hlen; i++) {
      if (healthy[i]->inflight == least) {
        HP_GROW(least_pool, llen, lcap, Backend *);
        least_pool[llen++] = healthy[i];
      }
    }
    pool = least_pool;
    plen = llen;
  }
  Backend **tickets = NULL;
  size_t tlen = 0;
  size_t tcap = 0;
  for (size_t i = 0; i < plen; i++) {
    for (int64_t n = 0; n < pool[i]->weight; n++) {
      HP_GROW(tickets, tlen, tcap, Backend *);
      tickets[tlen++] = pool[i];
    }
  }
  Backend *chosen = NULL;
  if (tlen > 0) {
    chosen = tickets[(size_t)(sim->cursor % (int64_t)tlen)];
    sim->cursor += 1;
  }
  free(tickets);
  free(least_pool);
  free(healthy);
  return chosen;
}

static char *take(Simulation *sim) {
  Backend *item = pick(sim);
  if (item == NULL) {
    return hp_strdup("");
  }
  item->inflight += 1;
  return hp_strdup(item->backend_id);
}

static char *route(Simulation *sim) { return take(sim); }

static const char *sticky_bound(Simulation *sim, const char *client_id) {
  for (size_t i = 0; i < sim->sticky_len; i++) {
    if (strcmp(sim->sticky[i].client_id, client_id) == 0) {
      return sim->sticky[i].backend_id;
    }
  }
  return NULL;
}

static void sticky_set(Simulation *sim, const char *client_id, const char *backend_id) {
  for (size_t i = 0; i < sim->sticky_len; i++) {
    if (strcmp(sim->sticky[i].client_id, client_id) == 0) {
      free(sim->sticky[i].backend_id);
      sim->sticky[i].backend_id = hp_strdup(backend_id);
      return;
    }
  }
  HP_GROW(sim->sticky, sim->sticky_len, sim->sticky_cap, Sticky);
  sim->sticky[sim->sticky_len].client_id = hp_strdup(client_id);
  sim->sticky[sim->sticky_len].backend_id = hp_strdup(backend_id);
  sim->sticky_len++;
}

static char *sticky(Simulation *sim, const char *client_id) {
  const char *bound = sticky_bound(sim, client_id);
  if (bound != NULL) {
    Backend *item = find_backend(sim, bound);
    if (item != NULL && item->health) {
      item->inflight += 1;
      return hp_strdup(item->backend_id);
    }
  }
  char *chosen = take(sim);
  if (chosen[0] != '\0') {
    sticky_set(sim, client_id, chosen);
  }
  return chosen;
}

static char *done(Simulation *sim, const char *backend_id) {
  Backend *item = find_backend(sim, backend_id);
  if (item == NULL || item->inflight <= 0) {
    return hp_strdup("invalid_request");
  }
  item->inflight -= 1;
  sim->use_least = 1;
  return hp_strdup("true");
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "add_backend") == 0) {
    text = add_backend(sim, arg_str(args, 0));
  } else if (strcmp(method, "route") == 0) {
    text = route(sim);
  } else if (strcmp(method, "set_health") == 0) {
    text = set_health(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "set_weight") == 0) {
    text = set_weight(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "sticky") == 0) {
    text = sticky(sim, arg_str(args, 0));
  } else if (strcmp(method, "done") == 0) {
    text = done(sim, arg_str(args, 0));
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
  for (size_t i = 0; i < sim->backend_len; i++) {
    free(sim->backends[i].backend_id);
  }
  for (size_t i = 0; i < sim->sticky_len; i++) {
    free(sim->sticky[i].client_id);
    free(sim->sticky[i].backend_id);
  }
  free(sim->backends);
  free(sim->sticky);
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
