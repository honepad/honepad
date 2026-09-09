#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *sku;
  char *name;
  int64_t qty;
  int64_t reserved;
} Item;

typedef struct {
  HonepadTarget base;
  Item *items;
  size_t item_len;
  size_t item_cap;
} Simulation;

static Item *find_item(Simulation *sim, const char *sku) {
  for (size_t i = 0; i < sim->item_len; i++) {
    if (strcmp(sim->items[i].sku, sku) == 0) {
      return &sim->items[i];
    }
  }
  return NULL;
}

static char *fmt_i64(int64_t n) {
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)n);
  return hp_strdup(buf);
}

static char *create_item(Simulation *sim, const char *sku, const char *name) {
  if (find_item(sim, sku) != NULL) {
    return hp_strdup("false");
  }
  HP_GROW(sim->items, sim->item_len, sim->item_cap, Item);
  sim->items[sim->item_len].sku = hp_strdup(sku);
  sim->items[sim->item_len].name = hp_strdup(name);
  sim->items[sim->item_len].qty = 0;
  sim->items[sim->item_len].reserved = 0;
  sim->item_len++;
  return hp_strdup("true");
}

static char *stock(Simulation *sim, const char *sku, int64_t delta) {
  Item *item = find_item(sim, sku);
  if (item == NULL) {
    return hp_strdup("");
  }
  int64_t nxt = item->qty + delta;
  if (nxt < item->reserved) {
    return hp_strdup("invalid_request");
  }
  item->qty = nxt;
  return fmt_i64(item->qty);
}

static char *get_qty(Simulation *sim, const char *sku) {
  Item *item = find_item(sim, sku);
  if (item == NULL) {
    return hp_strdup("");
  }
  return fmt_i64(item->qty);
}

static int cmp_low(const void *a, const void *b) {
  const Item *x = *(const Item *const *)a;
  const Item *y = *(const Item *const *)b;
  if (x->qty != y->qty) {
    return x->qty < y->qty ? -1 : 1;
  }
  return strcmp(x->sku, y->sku);
}

static char *list_low(Simulation *sim, int64_t threshold) {
  Item **matched = NULL;
  size_t mlen = 0;
  size_t mcap = 0;
  for (size_t i = 0; i < sim->item_len; i++) {
    if (sim->items[i].qty <= threshold) {
      HP_GROW(matched, mlen, mcap, Item *);
      matched[mlen++] = &sim->items[i];
    }
  }
  qsort(matched, mlen, sizeof(*matched), cmp_low);
  size_t cap = 1;
  for (size_t i = 0; i < mlen; i++) {
    cap += strlen(matched[i]->sku) + 32;
  }
  char *out = malloc(cap);
  if (out == NULL) {
    honepad_throw("oom");
  }
  out[0] = '\0';
  for (size_t i = 0; i < mlen; i++) {
    char buf[32];
    snprintf(buf, sizeof(buf), "(%lld)", (long long)matched[i]->qty);
    if (i > 0) {
      strcat(out, ", ");
    }
    strcat(out, matched[i]->sku);
    strcat(out, buf);
  }
  free(matched);
  return out;
}

static char *reserve(Simulation *sim, const char *sku, int64_t n) {
  Item *item = find_item(sim, sku);
  if (item == NULL || n <= 0 || item->reserved + n > item->qty) {
    return hp_strdup("invalid_request");
  }
  item->reserved += n;
  return hp_strdup("true");
}

static char *release(Simulation *sim, const char *sku, int64_t n) {
  Item *item = find_item(sim, sku);
  if (item == NULL || n <= 0 || n > item->reserved) {
    return hp_strdup("invalid_request");
  }
  item->reserved -= n;
  return hp_strdup("true");
}

static char *ship(Simulation *sim, const char *sku, int64_t n) {
  Item *item = find_item(sim, sku);
  if (item == NULL || n <= 0 || n > item->reserved) {
    return hp_strdup("invalid_request");
  }
  item->reserved -= n;
  item->qty -= n;
  return hp_strdup("true");
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "create_item") == 0) {
    text = create_item(sim, arg_str(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "stock") == 0) {
    text = stock(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "get_qty") == 0) {
    text = get_qty(sim, arg_str(args, 0));
  } else if (strcmp(method, "list_low") == 0) {
    text = list_low(sim, arg_i64(args, 0));
  } else if (strcmp(method, "reserve") == 0) {
    text = reserve(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "release") == 0) {
    text = release(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "ship") == 0) {
    text = ship(sim, arg_str(args, 0), arg_i64(args, 1));
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
  for (size_t i = 0; i < sim->item_len; i++) {
    free(sim->items[i].sku);
    free(sim->items[i].name);
  }
  free(sim->items);
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
