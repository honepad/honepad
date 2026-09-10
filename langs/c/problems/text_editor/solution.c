#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *buf;
  int64_t pos;
} EditorSnap;

typedef struct {
  HonepadTarget base;
  char *buf;
  size_t len;
  size_t cap;
  int64_t pos;
  EditorSnap *undo;
  size_t undo_len;
  size_t undo_cap;
  EditorSnap *redo;
  size_t redo_len;
  size_t redo_cap;
  int64_t sel_start;
  int64_t sel_end;
  char *clip;
} Simulation;

static char *fmt_i64(int64_t n) {
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)n);
  return hp_strdup(buf);
}

static void buf_reserve(Simulation *sim, size_t need) {
  if (need <= sim->cap) {
    return;
  }
  size_t cap = sim->cap ? sim->cap : 8;
  while (cap < need) {
    cap *= 2;
  }
  char *next = realloc(sim->buf, cap);
  if (next == NULL) {
    honepad_throw("oom");
  }
  sim->buf = next;
  sim->cap = cap;
}

static void buf_insert(Simulation *sim, size_t at, const char *text) {
  size_t n = strlen(text);
  buf_reserve(sim, sim->len + n + 1);
  memmove(sim->buf + at + n, sim->buf + at, sim->len - at);
  memcpy(sim->buf + at, text, n);
  sim->len += n;
  sim->buf[sim->len] = '\0';
}

static char *buf_erase(Simulation *sim, size_t at, size_t n) {
  char *deleted = malloc(n + 1);
  if (deleted == NULL) {
    honepad_throw("oom");
  }
  memcpy(deleted, sim->buf + at, n);
  deleted[n] = '\0';
  memmove(sim->buf + at, sim->buf + at + n, sim->len - at - n);
  sim->len -= n;
  sim->buf[sim->len] = '\0';
  return deleted;
}

static void free_snaps(EditorSnap *snaps, size_t n) {
  for (size_t i = 0; i < n; i++) {
    free(snaps[i].buf);
  }
}

static void push(Simulation *sim) {
  HP_GROW(sim->undo, sim->undo_len, sim->undo_cap, EditorSnap);
  sim->undo[sim->undo_len].buf = hp_strdup(sim->buf ? sim->buf : "");
  sim->undo[sim->undo_len].pos = sim->pos;
  sim->undo_len++;
  free_snaps(sim->redo, sim->redo_len);
  sim->redo_len = 0;
  sim->sel_start = -1;
  sim->sel_end = -1;
}

static char *insert_at(Simulation *sim, int64_t at, const char *text) {
  if (at < 0 || at > (int64_t)sim->len) {
    return hp_strdup("invalid_request");
  }
  push(sim);
  buf_insert(sim, (size_t)at, text);
  return fmt_i64((int64_t)sim->len);
}

static char *erase_at(Simulation *sim, int64_t at, int64_t n) {
  if (n <= 0 || at < 0 || at + n > (int64_t)sim->len) {
    return hp_strdup("invalid_request");
  }
  push(sim);
  char *deleted = buf_erase(sim, (size_t)at, (size_t)n);
  if (sim->pos > (int64_t)sim->len) {
    sim->pos = (int64_t)sim->len;
  }
  return deleted;
}

static char *get_text(Simulation *sim) {
  return hp_strdup(sim->buf ? sim->buf : "");
}

static char *length_of(Simulation *sim) {
  return fmt_i64((int64_t)sim->len);
}

static char *move_to(Simulation *sim, int64_t at) {
  if (at < 0 || at > (int64_t)sim->len) {
    return hp_strdup("invalid_request");
  }
  sim->pos = at;
  return hp_strdup("true");
}

static char *type_text(Simulation *sim, const char *text) {
  push(sim);
  int64_t at = sim->pos;
  buf_insert(sim, (size_t)at, text);
  sim->pos = at + (int64_t)strlen(text);
  return fmt_i64((int64_t)sim->len);
}

static char *cursor_of(Simulation *sim) {
  return fmt_i64(sim->pos);
}

static char *undo_op(Simulation *sim) {
  if (sim->undo_len == 0) {
    return hp_strdup("false");
  }
  HP_GROW(sim->redo, sim->redo_len, sim->redo_cap, EditorSnap);
  sim->redo[sim->redo_len].buf = hp_strdup(sim->buf ? sim->buf : "");
  sim->redo[sim->redo_len].pos = sim->pos;
  sim->redo_len++;
  EditorSnap snap = sim->undo[--sim->undo_len];
  free(sim->buf);
  sim->buf = snap.buf;
  sim->len = strlen(sim->buf);
  sim->cap = sim->len + 1;
  sim->pos = snap.pos;
  sim->sel_start = -1;
  sim->sel_end = -1;
  return hp_strdup("true");
}

static char *redo_op(Simulation *sim) {
  if (sim->redo_len == 0) {
    return hp_strdup("false");
  }
  HP_GROW(sim->undo, sim->undo_len, sim->undo_cap, EditorSnap);
  sim->undo[sim->undo_len].buf = hp_strdup(sim->buf ? sim->buf : "");
  sim->undo[sim->undo_len].pos = sim->pos;
  sim->undo_len++;
  EditorSnap snap = sim->redo[--sim->redo_len];
  free(sim->buf);
  sim->buf = snap.buf;
  sim->len = strlen(sim->buf);
  sim->cap = sim->len + 1;
  sim->pos = snap.pos;
  sim->sel_start = -1;
  sim->sel_end = -1;
  return hp_strdup("true");
}

static char *select_span(Simulation *sim, int64_t start, int64_t end) {
  if (start < 0 || end < 0 || start > end || end > (int64_t)sim->len) {
    return hp_strdup("invalid_request");
  }
  sim->sel_start = start;
  sim->sel_end = end;
  return hp_strdup("true");
}

static char *cut_sel(Simulation *sim) {
  if (sim->sel_start < 0 || sim->sel_start == sim->sel_end) {
    return hp_strdup("invalid_request");
  }
  size_t start = (size_t)sim->sel_start;
  size_t n = (size_t)(sim->sel_end - sim->sel_start);
  char *text = buf_erase(sim, start, n);
  free(sim->clip);
  sim->clip = hp_strdup(text);
  sim->pos = sim->sel_start;
  sim->sel_start = -1;
  sim->sel_end = -1;
  return text;
}

static char *copy_sel(Simulation *sim) {
  if (sim->sel_start < 0 || sim->sel_start == sim->sel_end) {
    return hp_strdup("invalid_request");
  }
  size_t start = (size_t)sim->sel_start;
  size_t n = (size_t)(sim->sel_end - sim->sel_start);
  free(sim->clip);
  sim->clip = malloc(n + 1);
  if (sim->clip == NULL) {
    honepad_throw("oom");
  }
  memcpy(sim->clip, sim->buf + start, n);
  sim->clip[n] = '\0';
  return hp_strdup(sim->clip);
}

static char *paste_clip(Simulation *sim) {
  if (sim->clip == NULL || sim->clip[0] == '\0') {
    return hp_strdup("invalid_request");
  }
  int64_t at = sim->pos;
  buf_insert(sim, (size_t)at, sim->clip);
  sim->pos = at + (int64_t)strlen(sim->clip);
  return fmt_i64((int64_t)sim->len);
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "insert") == 0) {
    text = insert_at(sim, arg_i64(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "erase") == 0) {
    text = erase_at(sim, arg_i64(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "get_text") == 0) {
    text = get_text(sim);
  } else if (strcmp(method, "length") == 0) {
    text = length_of(sim);
  } else if (strcmp(method, "move") == 0) {
    text = move_to(sim, arg_i64(args, 0));
  } else if (strcmp(method, "type_text") == 0) {
    text = type_text(sim, arg_str(args, 0));
  } else if (strcmp(method, "cursor") == 0) {
    text = cursor_of(sim);
  } else if (strcmp(method, "undo") == 0) {
    text = undo_op(sim);
  } else if (strcmp(method, "redo") == 0) {
    text = redo_op(sim);
  } else if (strcmp(method, "select") == 0) {
    text = select_span(sim, arg_i64(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "cut") == 0) {
    text = cut_sel(sim);
  } else if (strcmp(method, "copy_sel") == 0) {
    text = copy_sel(sim);
  } else if (strcmp(method, "paste") == 0) {
    text = paste_clip(sim);
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
  free(sim->buf);
  free_snaps(sim->undo, sim->undo_len);
  free(sim->undo);
  free_snaps(sim->redo, sim->redo_len);
  free(sim->redo);
  free(sim->clip);
  free(sim);
}

static HonepadTarget *Simulation_new(void) {
  Simulation *sim = calloc(1, sizeof(*sim));
  if (sim == NULL) {
    fprintf(stderr, "oom\n");
    exit(2);
  }
  sim->buf = hp_strdup("");
  sim->cap = 1;
  sim->sel_start = -1;
  sim->sel_end = -1;
  sim->clip = hp_strdup("");
  sim->base.call = simulation_call;
  sim->base.free_fn = simulation_free;
  return &sim->base;
}

#endif
