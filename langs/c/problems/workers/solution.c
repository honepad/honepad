#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  int64_t start;
  int64_t end;
  int64_t rate;
  char *position;
} WorkSession;

typedef struct {
  char *position;
  int64_t compensation;
  int64_t start_timestamp;
} Promo;

typedef struct {
  char *worker_id;
  char *position;
  int64_t compensation;
  int in_office;
  int has_entered;
  int64_t entered_at;
  WorkSession *finished;
  size_t fin_len;
  size_t fin_cap;
  int has_promo;
  Promo promo;
} Worker;

typedef struct {
  HonepadTarget base;
  Worker *workers;
  size_t worker_len;
  size_t worker_cap;
} Simulation;

static Worker *find_worker(Simulation *sim, const char *worker_id) {
  for (size_t i = 0; i < sim->worker_len; i++) {
    if (strcmp(sim->workers[i].worker_id, worker_id) == 0) {
      return &sim->workers[i];
    }
  }
  return NULL;
}

static int64_t total_time(const Worker *worker) {
  int64_t sum = 0;
  for (size_t i = 0; i < worker->fin_len; i++) {
    sum += worker->finished[i].end - worker->finished[i].start;
  }
  return sum;
}

static int64_t position_time(const Worker *worker, const char *position) {
  int64_t sum = 0;
  for (size_t i = 0; i < worker->fin_len; i++) {
    if (strcmp(worker->finished[i].position, position) == 0) {
      sum += worker->finished[i].end - worker->finished[i].start;
    }
  }
  return sum;
}

static void apply_promo_on_enter(Worker *worker, int64_t timestamp) {
  if (!worker->has_promo) {
    return;
  }
  if (timestamp >= worker->promo.start_timestamp) {
    free(worker->position);
    worker->position = hp_strdup(worker->promo.position);
    worker->compensation = worker->promo.compensation;
    free(worker->promo.position);
    worker->promo.position = NULL;
    worker->has_promo = 0;
  }
}

static char *add_worker(Simulation *sim, const char *worker_id, const char *position, int64_t compensation) {
  if (find_worker(sim, worker_id) != NULL) {
    return hp_strdup("false");
  }
  HP_GROW(sim->workers, sim->worker_len, sim->worker_cap, Worker);
  Worker *worker = &sim->workers[sim->worker_len++];
  memset(worker, 0, sizeof(*worker));
  worker->worker_id = hp_strdup(worker_id);
  worker->position = hp_strdup(position);
  worker->compensation = compensation;
  return hp_strdup("true");
}

static char *register_worker(Simulation *sim, const char *worker_id, int64_t timestamp) {
  Worker *worker = find_worker(sim, worker_id);
  if (worker == NULL) {
    return hp_strdup("invalid_request");
  }
  if (worker->in_office) {
    HP_GROW(worker->finished, worker->fin_len, worker->fin_cap, WorkSession);
    WorkSession *session = &worker->finished[worker->fin_len++];
    session->start = worker->entered_at;
    session->end = timestamp;
    session->rate = worker->compensation;
    session->position = hp_strdup(worker->position);
    worker->in_office = 0;
    worker->has_entered = 0;
    return hp_strdup("registered");
  }
  apply_promo_on_enter(worker, timestamp);
  worker->in_office = 1;
  worker->has_entered = 1;
  worker->entered_at = timestamp;
  return hp_strdup("registered");
}

static char *get_worker(Simulation *sim, const char *worker_id) {
  Worker *worker = find_worker(sim, worker_id);
  if (worker == NULL) {
    return hp_strdup("");
  }
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)total_time(worker));
  return hp_strdup(buf);
}

typedef struct {
  Worker *worker;
  int64_t time;
} Rank;

static int cmp_rank(const void *a, const void *b) {
  const Rank *x = a;
  const Rank *y = b;
  if (x->time != y->time) {
    return x->time > y->time ? -1 : 1;
  }
  return strcmp(x->worker->worker_id, y->worker->worker_id);
}

static char *top_n_workers(Simulation *sim, int64_t n, const char *position) {
  Rank *matched = NULL;
  size_t mlen = 0;
  size_t mcap = 0;
  for (size_t i = 0; i < sim->worker_len; i++) {
    if (strcmp(sim->workers[i].position, position) == 0) {
      HP_GROW(matched, mlen, mcap, Rank);
      matched[mlen].worker = &sim->workers[i];
      matched[mlen].time = position_time(&sim->workers[i], position);
      mlen++;
    }
  }
  qsort(matched, mlen, sizeof(*matched), cmp_rank);
  if (n >= 0 && (size_t)n < mlen) {
    mlen = (size_t)n;
  }
  size_t cap = 1;
  for (size_t i = 0; i < mlen; i++) {
    cap += strlen(matched[i].worker->worker_id) + 32;
  }
  char *out = malloc(cap);
  if (out == NULL) {
    honepad_throw("oom");
  }
  out[0] = '\0';
  for (size_t i = 0; i < mlen; i++) {
    char buf[32];
    snprintf(buf, sizeof(buf), "(%lld)", (long long)matched[i].time);
    if (i > 0) {
      strcat(out, ", ");
    }
    strcat(out, matched[i].worker->worker_id);
    strcat(out, buf);
  }
  free(matched);
  return out;
}

static char *promote(
    Simulation *sim,
    const char *worker_id,
    const char *new_position,
    int64_t new_compensation,
    int64_t start_timestamp) {
  Worker *worker = find_worker(sim, worker_id);
  if (worker == NULL || worker->has_promo) {
    return hp_strdup("invalid_request");
  }
  worker->promo.position = hp_strdup(new_position);
  worker->promo.compensation = new_compensation;
  worker->promo.start_timestamp = start_timestamp;
  worker->has_promo = 1;
  return hp_strdup("success");
}

static int64_t max64(int64_t a, int64_t b) { return a > b ? a : b; }
static int64_t min64(int64_t a, int64_t b) { return a < b ? a : b; }

static char *calc_salary(Simulation *sim, const char *worker_id, int64_t start_timestamp, int64_t end_timestamp) {
  Worker *worker = find_worker(sim, worker_id);
  if (worker == NULL) {
    return hp_strdup("");
  }
  int64_t total = 0;
  for (size_t i = 0; i < worker->fin_len; i++) {
    int64_t lo = max64(worker->finished[i].start, start_timestamp);
    int64_t hi = min64(worker->finished[i].end, end_timestamp);
    if (hi > lo) {
      total += (hi - lo) * worker->finished[i].rate;
    }
  }
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)total);
  return hp_strdup(buf);
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "add_worker") == 0) {
    text = add_worker(sim, arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2));
  } else if (strcmp(method, "register") == 0) {
    text = register_worker(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "get") == 0) {
    text = get_worker(sim, arg_str(args, 0));
  } else if (strcmp(method, "top_n_workers") == 0) {
    text = top_n_workers(sim, arg_i64(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "promote") == 0) {
    text = promote(sim, arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2), arg_i64(args, 3));
  } else if (strcmp(method, "calc_salary") == 0) {
    text = calc_salary(sim, arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2));
  } else {
    char buf[128];
    snprintf(buf, sizeof(buf), "missing method %s", method);
    honepad_throw(buf);
  }
  JsonVal *out = json_str(text);
  free(text);
  return out;
}

static void worker_free(Worker *worker) {
  free(worker->worker_id);
  free(worker->position);
  for (size_t i = 0; i < worker->fin_len; i++) {
    free(worker->finished[i].position);
  }
  free(worker->finished);
  free(worker->promo.position);
}

static void simulation_free(HonepadTarget *self) {
  Simulation *sim = (Simulation *)self;
  for (size_t i = 0; i < sim->worker_len; i++) {
    worker_free(&sim->workers[i]);
  }
  free(sim->workers);
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
