#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *name;
  int64_t size;
  char *owner;
} StoredFile;

typedef struct {
  char *user_id;
  int has_cap;
  int64_t cap;
} UserCap;

typedef struct {
  char *name;
  int64_t size;
} SnapFile;

typedef struct {
  char *user_id;
  SnapFile *files;
  size_t file_len;
} UserBackup;

typedef struct {
  HonepadTarget base;
  StoredFile *files;
  size_t file_len;
  size_t file_cap;
  char **order;
  size_t order_len;
  size_t order_cap;
  UserCap *caps;
  size_t cap_len;
  size_t cap_cap;
  UserBackup *backups;
  size_t backup_len;
  size_t backup_cap;
} Simulation;

static StoredFile *find_file(Simulation *sim, const char *name) {
  for (size_t i = 0; i < sim->file_len; i++) {
    if (strcmp(sim->files[i].name, name) == 0) {
      return &sim->files[i];
    }
  }
  return NULL;
}

static UserCap *find_cap(Simulation *sim, const char *user_id) {
  for (size_t i = 0; i < sim->cap_len; i++) {
    if (strcmp(sim->caps[i].user_id, user_id) == 0) {
      return &sim->caps[i];
    }
  }
  return NULL;
}

static int64_t used(Simulation *sim, const char *user_id) {
  int64_t sum = 0;
  for (size_t i = 0; i < sim->file_len; i++) {
    if (strcmp(sim->files[i].owner, user_id) == 0) {
      sum += sim->files[i].size;
    }
  }
  return sum;
}

static int remaining(Simulation *sim, const char *user_id, int64_t *out) {
  UserCap *cap = find_cap(sim, user_id);
  if (cap == NULL || !cap->has_cap) {
    return 0;
  }
  *out = cap->cap - used(sim, user_id);
  return 1;
}

static void order_remove(Simulation *sim, const char *name) {
  size_t w = 0;
  for (size_t i = 0; i < sim->order_len; i++) {
    if (strcmp(sim->order[i], name) == 0) {
      free(sim->order[i]);
      continue;
    }
    sim->order[w++] = sim->order[i];
  }
  sim->order_len = w;
}

static char *add_file(Simulation *sim, const char *name, int64_t size) {
  if (find_file(sim, name) != NULL) {
    return hp_strdup("false");
  }
  HP_GROW(sim->files, sim->file_len, sim->file_cap, StoredFile);
  sim->files[sim->file_len].name = hp_strdup(name);
  sim->files[sim->file_len].size = size;
  sim->files[sim->file_len].owner = hp_strdup("admin");
  sim->file_len++;
  HP_GROW(sim->order, sim->order_len, sim->order_cap, char *);
  sim->order[sim->order_len++] = hp_strdup(name);
  return hp_strdup("true");
}

static char *get_file_size(Simulation *sim, const char *name) {
  StoredFile *file = find_file(sim, name);
  if (file == NULL) {
    return hp_strdup("");
  }
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)file->size);
  return hp_strdup(buf);
}

static char *delete_file(Simulation *sim, const char *name) {
  for (size_t i = 0; i < sim->file_len; i++) {
    if (strcmp(sim->files[i].name, name) == 0) {
      int64_t size = sim->files[i].size;
      free(sim->files[i].name);
      free(sim->files[i].owner);
      memmove(sim->files + i, sim->files + i + 1, (sim->file_len - i - 1) * sizeof(StoredFile));
      sim->file_len--;
      order_remove(sim, name);
      char buf[32];
      snprintf(buf, sizeof(buf), "%lld", (long long)size);
      return hp_strdup(buf);
    }
  }
  return hp_strdup("");
}

static char *copy_file(Simulation *sim, const char *source, const char *dest) {
  StoredFile *src = find_file(sim, source);
  if (src == NULL) {
    return hp_strdup("");
  }
  int64_t src_size = src->size;
  if (strcmp(source, dest) == 0) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%lld", (long long)src_size);
    return hp_strdup(buf);
  }
  StoredFile *dest_item = find_file(sim, dest);
  const char *owner = dest_item == NULL ? src->owner : dest_item->owner;
  int64_t extra = dest_item == NULL ? src_size : src_size - dest_item->size;
  int64_t left = 0;
  if (remaining(sim, owner, &left) && extra > left) {
    return hp_strdup("");
  }
  if (dest_item == NULL) {
    HP_GROW(sim->files, sim->file_len, sim->file_cap, StoredFile);
    sim->files[sim->file_len].name = hp_strdup(dest);
    sim->files[sim->file_len].size = src_size;
    sim->files[sim->file_len].owner = hp_strdup(owner);
    sim->file_len++;
    HP_GROW(sim->order, sim->order_len, sim->order_cap, char *);
    sim->order[sim->order_len++] = hp_strdup(dest);
  } else {
    dest_item->size = src_size;
  }
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)src_size);
  return hp_strdup(buf);
}

typedef struct {
  char *name;
  int64_t size;
} FileRef;

static int cmp_largest(const void *a, const void *b) {
  const FileRef *x = a;
  const FileRef *y = b;
  if (x->size != y->size) {
    return x->size > y->size ? -1 : 1;
  }
  return strcmp(x->name, y->name);
}

static char *get_n_largest(Simulation *sim, const char *prefix, int64_t n) {
  FileRef *matched = NULL;
  size_t mlen = 0;
  size_t mcap = 0;
  size_t plen = strlen(prefix);
  for (size_t i = 0; i < sim->file_len; i++) {
    if (strncmp(sim->files[i].name, prefix, plen) == 0) {
      HP_GROW(matched, mlen, mcap, FileRef);
      matched[mlen].name = sim->files[i].name;
      matched[mlen].size = sim->files[i].size;
      mlen++;
    }
  }
  qsort(matched, mlen, sizeof(*matched), cmp_largest);
  if (n >= 0 && (size_t)n < mlen) {
    mlen = (size_t)n;
  }
  size_t cap = 1;
  for (size_t i = 0; i < mlen; i++) {
    cap += strlen(matched[i].name) + 32;
  }
  char *out = malloc(cap);
  if (out == NULL) {
    honepad_throw("oom");
  }
  out[0] = '\0';
  for (size_t i = 0; i < mlen; i++) {
    char buf[32];
    snprintf(buf, sizeof(buf), "(%lld)", (long long)matched[i].size);
    if (i > 0) {
      strcat(out, ", ");
    }
    strcat(out, matched[i].name);
    strcat(out, buf);
  }
  free(matched);
  return out;
}

static char *add_user(Simulation *sim, const char *user_id, int64_t cap) {
  if (find_cap(sim, user_id) != NULL) {
    return hp_strdup("false");
  }
  HP_GROW(sim->caps, sim->cap_len, sim->cap_cap, UserCap);
  sim->caps[sim->cap_len].user_id = hp_strdup(user_id);
  sim->caps[sim->cap_len].has_cap = 1;
  sim->caps[sim->cap_len].cap = cap;
  sim->cap_len++;
  return hp_strdup("true");
}

static char *add_file_by(Simulation *sim, const char *user_id, const char *name, int64_t size) {
  if (find_cap(sim, user_id) == NULL || find_file(sim, name) != NULL) {
    return hp_strdup("");
  }
  int64_t left = 0;
  if (remaining(sim, user_id, &left) && size > left) {
    return hp_strdup("");
  }
  HP_GROW(sim->files, sim->file_len, sim->file_cap, StoredFile);
  sim->files[sim->file_len].name = hp_strdup(name);
  sim->files[sim->file_len].size = size;
  sim->files[sim->file_len].owner = hp_strdup(user_id);
  sim->file_len++;
  HP_GROW(sim->order, sim->order_len, sim->order_cap, char *);
  sim->order[sim->order_len++] = hp_strdup(name);
  if (!remaining(sim, user_id, &left)) {
    return hp_strdup("");
  }
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)left);
  return hp_strdup(buf);
}

static void drop_backup(Simulation *sim, const char *user_id) {
  for (size_t i = 0; i < sim->backup_len; i++) {
    if (strcmp(sim->backups[i].user_id, user_id) == 0) {
      for (size_t j = 0; j < sim->backups[i].file_len; j++) {
        free(sim->backups[i].files[j].name);
      }
      free(sim->backups[i].files);
      free(sim->backups[i].user_id);
      memmove(sim->backups + i, sim->backups + i + 1, (sim->backup_len - i - 1) * sizeof(UserBackup));
      sim->backup_len--;
      return;
    }
  }
}

static char *merge_user(Simulation *sim, const char *user_id1, const char *user_id2) {
  if (strcmp(user_id1, user_id2) == 0) {
    return hp_strdup("");
  }
  UserCap *c1 = find_cap(sim, user_id1);
  UserCap *c2 = find_cap(sim, user_id2);
  if (c1 == NULL || c2 == NULL || !c1->has_cap || !c2->has_cap) {
    return hp_strdup("");
  }
  c1->cap = c1->cap + c2->cap;
  for (size_t i = 0; i < sim->file_len; i++) {
    if (strcmp(sim->files[i].owner, user_id2) == 0) {
      free(sim->files[i].owner);
      sim->files[i].owner = hp_strdup(user_id1);
    }
  }
  size_t idx = (size_t)(c2 - sim->caps);
  free(c2->user_id);
  memmove(sim->caps + idx, sim->caps + idx + 1, (sim->cap_len - idx - 1) * sizeof(UserCap));
  sim->cap_len--;
  drop_backup(sim, user_id2);
  int64_t left = 0;
  if (!remaining(sim, user_id1, &left)) {
    return hp_strdup("");
  }
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)left);
  return hp_strdup(buf);
}

static UserBackup *find_backup(Simulation *sim, const char *user_id) {
  for (size_t i = 0; i < sim->backup_len; i++) {
    if (strcmp(sim->backups[i].user_id, user_id) == 0) {
      return &sim->backups[i];
    }
  }
  return NULL;
}

static char *backup_user(Simulation *sim, const char *user_id) {
  if (find_cap(sim, user_id) == NULL) {
    return hp_strdup("");
  }
  drop_backup(sim, user_id);
  SnapFile *snap = NULL;
  size_t slen = 0;
  size_t scap = 0;
  for (size_t i = 0; i < sim->order_len; i++) {
    StoredFile *file = find_file(sim, sim->order[i]);
    if (file != NULL && strcmp(file->owner, user_id) == 0) {
      HP_GROW(snap, slen, scap, SnapFile);
      snap[slen].name = hp_strdup(file->name);
      snap[slen].size = file->size;
      slen++;
    }
  }
  HP_GROW(sim->backups, sim->backup_len, sim->backup_cap, UserBackup);
  sim->backups[sim->backup_len].user_id = hp_strdup(user_id);
  sim->backups[sim->backup_len].files = snap;
  sim->backups[sim->backup_len].file_len = slen;
  sim->backup_len++;
  char buf[32];
  snprintf(buf, sizeof(buf), "%zu", slen);
  return hp_strdup(buf);
}

static char *restore_user(Simulation *sim, const char *user_id) {
  if (find_cap(sim, user_id) == NULL) {
    return hp_strdup("");
  }
  char **owned = NULL;
  size_t olen = 0;
  size_t ocap = 0;
  for (size_t i = 0; i < sim->file_len; i++) {
    if (strcmp(sim->files[i].owner, user_id) == 0) {
      HP_GROW(owned, olen, ocap, char *);
      owned[olen++] = hp_strdup(sim->files[i].name);
    }
  }
  for (size_t i = 0; i < olen; i++) {
    char *tmp = delete_file(sim, owned[i]);
    free(tmp);
    free(owned[i]);
  }
  free(owned);
  UserBackup *backup = find_backup(sim, user_id);
  if (backup == NULL) {
    return hp_strdup("0");
  }
  int64_t restored = 0;
  for (size_t i = 0; i < backup->file_len; i++) {
    if (find_file(sim, backup->files[i].name) != NULL) {
      continue;
    }
    int64_t left = 0;
    if (remaining(sim, user_id, &left) && backup->files[i].size > left) {
      continue;
    }
    HP_GROW(sim->files, sim->file_len, sim->file_cap, StoredFile);
    sim->files[sim->file_len].name = hp_strdup(backup->files[i].name);
    sim->files[sim->file_len].size = backup->files[i].size;
    sim->files[sim->file_len].owner = hp_strdup(user_id);
    sim->file_len++;
    HP_GROW(sim->order, sim->order_len, sim->order_cap, char *);
    sim->order[sim->order_len++] = hp_strdup(backup->files[i].name);
    restored += 1;
  }
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)restored);
  return hp_strdup(buf);
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "add_file") == 0) {
    text = add_file(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "copy_file") == 0) {
    text = copy_file(sim, arg_str(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "get_file_size") == 0) {
    text = get_file_size(sim, arg_str(args, 0));
  } else if (strcmp(method, "delete_file") == 0) {
    text = delete_file(sim, arg_str(args, 0));
  } else if (strcmp(method, "get_n_largest") == 0) {
    text = get_n_largest(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "add_user") == 0) {
    text = add_user(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "add_file_by") == 0) {
    text = add_file_by(sim, arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2));
  } else if (strcmp(method, "merge_user") == 0) {
    text = merge_user(sim, arg_str(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "backup_user") == 0) {
    text = backup_user(sim, arg_str(args, 0));
  } else if (strcmp(method, "restore_user") == 0) {
    text = restore_user(sim, arg_str(args, 0));
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
  for (size_t i = 0; i < sim->file_len; i++) {
    free(sim->files[i].name);
    free(sim->files[i].owner);
  }
  free(sim->files);
  for (size_t i = 0; i < sim->order_len; i++) {
    free(sim->order[i]);
  }
  free(sim->order);
  for (size_t i = 0; i < sim->cap_len; i++) {
    free(sim->caps[i].user_id);
  }
  free(sim->caps);
  for (size_t i = 0; i < sim->backup_len; i++) {
    for (size_t j = 0; j < sim->backups[i].file_len; j++) {
      free(sim->backups[i].files[j].name);
    }
    free(sim->backups[i].files);
    free(sim->backups[i].user_id);
  }
  free(sim->backups);
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
  sim->caps = calloc(1, sizeof(UserCap));
  if (sim->caps == NULL) {
    fprintf(stderr, "oom\n");
    exit(2);
  }
  sim->cap_cap = 1;
  sim->caps[0].user_id = malloc(6);
  if (sim->caps[0].user_id == NULL) {
    fprintf(stderr, "oom\n");
    exit(2);
  }
  memcpy(sim->caps[0].user_id, "admin", 6);
  sim->caps[0].has_cap = 0;
  sim->caps[0].cap = 0;
  sim->cap_len = 1;
  return &sim->base;
}

#endif
