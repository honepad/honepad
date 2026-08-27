#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *name;
  char *value;
  int has_expiry;
  int64_t expiry;
} FieldVal;

typedef struct {
  char *key;
  FieldVal *fields;
  size_t field_len;
  size_t field_cap;
} KeyRow;

typedef struct {
  char *key;
  char *name;
  char *value;
  int has_expiry;
  int64_t expiry_delta;
} BackupField;

typedef struct {
  int64_t timestamp;
  BackupField *fields;
  size_t field_len;
} Backup;

typedef struct {
  HonepadTarget base;
  KeyRow *keys;
  size_t key_len;
  size_t key_cap;
  Backup *backups;
  size_t backup_len;
  size_t backup_cap;
} InMemoryDatabase;

static KeyRow *find_key(InMemoryDatabase *db, const char *key) {
  for (size_t i = 0; i < db->key_len; i++) {
    if (strcmp(db->keys[i].key, key) == 0) {
      return &db->keys[i];
    }
  }
  return NULL;
}

static FieldVal *find_field(KeyRow *row, const char *name) {
  for (size_t i = 0; i < row->field_len; i++) {
    if (strcmp(row->fields[i].name, name) == 0) {
      return &row->fields[i];
    }
  }
  return NULL;
}

static KeyRow *ensure_key(InMemoryDatabase *db, const char *key) {
  KeyRow *row = find_key(db, key);
  if (row != NULL) {
    return row;
  }
  HP_GROW(db->keys, db->key_len, db->key_cap, KeyRow);
  row = &db->keys[db->key_len++];
  memset(row, 0, sizeof(*row));
  row->key = hp_strdup(key);
  return row;
}

static void set_internal(
    InMemoryDatabase *db,
    const char *key,
    const char *field,
    const char *value,
    int has_expiry,
    int64_t expiry) {
  KeyRow *row = ensure_key(db, key);
  FieldVal *existing = find_field(row, field);
  if (existing != NULL) {
    free(existing->value);
    existing->value = hp_strdup(value);
    existing->has_expiry = has_expiry;
    existing->expiry = expiry;
    return;
  }
  HP_GROW(row->fields, row->field_len, row->field_cap, FieldVal);
  FieldVal *item = &row->fields[row->field_len++];
  item->name = hp_strdup(field);
  item->value = hp_strdup(value);
  item->has_expiry = has_expiry;
  item->expiry = expiry;
}

static int is_alive(InMemoryDatabase *db, const char *key, const char *field, int64_t timestamp) {
  KeyRow *row = find_key(db, key);
  if (row == NULL) {
    return 0;
  }
  FieldVal *item = find_field(row, field);
  if (item == NULL) {
    return 0;
  }
  if (!item->has_expiry) {
    return 1;
  }
  return timestamp < item->expiry;
}

static const char *get_value(InMemoryDatabase *db, const char *key, const char *field) {
  KeyRow *row = find_key(db, key);
  if (row == NULL) {
    return "";
  }
  FieldVal *item = find_field(row, field);
  if (item == NULL) {
    return "";
  }
  return item->value;
}

static int delete_field(InMemoryDatabase *db, const char *key, const char *field) {
  KeyRow *row = find_key(db, key);
  if (row == NULL) {
    return 0;
  }
  for (size_t i = 0; i < row->field_len; i++) {
    if (strcmp(row->fields[i].name, field) == 0) {
      free(row->fields[i].name);
      free(row->fields[i].value);
      memmove(row->fields + i, row->fields + i + 1, (row->field_len - i - 1) * sizeof(FieldVal));
      row->field_len--;
      return 1;
    }
  }
  return 0;
}

static int cmp_cstr(const void *a, const void *b) {
  const char *const *x = a;
  const char *const *y = b;
  return strcmp(*x, *y);
}

static char *format_scan(char **names, size_t n, KeyRow *row) {
  size_t cap = 1;
  for (size_t i = 0; i < n; i++) {
    FieldVal *item = find_field(row, names[i]);
    cap += strlen(names[i]) + strlen(item->value) + 8;
  }
  char *out = malloc(cap);
  if (out == NULL) {
    honepad_throw("oom");
  }
  out[0] = '\0';
  for (size_t i = 0; i < n; i++) {
    FieldVal *item = find_field(row, names[i]);
    if (i > 0) {
      strcat(out, ", ");
    }
    strcat(out, names[i]);
    strcat(out, "(");
    strcat(out, item->value);
    strcat(out, ")");
  }
  return out;
}

static char *scan_key(InMemoryDatabase *db, const char *key, const char *prefix, int timed, int64_t timestamp) {
  KeyRow *row = find_key(db, key);
  if (row == NULL) {
    return hp_strdup("");
  }
  char **names = NULL;
  size_t n = 0;
  size_t cap = 0;
  size_t plen = prefix ? strlen(prefix) : 0;
  for (size_t i = 0; i < row->field_len; i++) {
    if (prefix != NULL && strncmp(row->fields[i].name, prefix, plen) != 0) {
      continue;
    }
    if (timed && !is_alive(db, key, row->fields[i].name, timestamp)) {
      continue;
    }
    HP_GROW(names, n, cap, char *);
    names[n++] = row->fields[i].name;
  }
  qsort(names, n, sizeof(*names), cmp_cstr);
  char *out = format_scan(names, n, row);
  free(names);
  return out;
}

static char *do_backup(InMemoryDatabase *db, int64_t timestamp) {
  BackupField *fields = NULL;
  size_t flen = 0;
  size_t fcap = 0;
  size_t key_count = 0;
  for (size_t i = 0; i < db->key_len; i++) {
    int used = 0;
    for (size_t j = 0; j < db->keys[i].field_len; j++) {
      FieldVal *item = &db->keys[i].fields[j];
      if (!is_alive(db, db->keys[i].key, item->name, timestamp)) {
        continue;
      }
      HP_GROW(fields, flen, fcap, BackupField);
      fields[flen].key = hp_strdup(db->keys[i].key);
      fields[flen].name = hp_strdup(item->name);
      fields[flen].value = hp_strdup(item->value);
      fields[flen].has_expiry = item->has_expiry;
      fields[flen].expiry_delta = item->has_expiry ? item->expiry - timestamp : 0;
      flen++;
      used = 1;
    }
    if (used) {
      key_count++;
    }
  }
  HP_GROW(db->backups, db->backup_len, db->backup_cap, Backup);
  db->backups[db->backup_len].timestamp = timestamp;
  db->backups[db->backup_len].fields = fields;
  db->backups[db->backup_len].field_len = flen;
  db->backup_len++;
  char buf[32];
  snprintf(buf, sizeof(buf), "%zu", key_count);
  return hp_strdup(buf);
}

static void clear_db(InMemoryDatabase *db) {
  for (size_t i = 0; i < db->key_len; i++) {
    for (size_t j = 0; j < db->keys[i].field_len; j++) {
      free(db->keys[i].fields[j].name);
      free(db->keys[i].fields[j].value);
    }
    free(db->keys[i].fields);
    free(db->keys[i].key);
  }
  free(db->keys);
  db->keys = NULL;
  db->key_len = 0;
  db->key_cap = 0;
}

static char *do_restore(InMemoryDatabase *db, int64_t timestamp, int64_t timestamp_to_restore) {
  int idx = -1;
  for (size_t i = 0; i < db->backup_len; i++) {
    if (db->backups[i].timestamp <= timestamp_to_restore) {
      idx = (int)i;
    }
  }
  clear_db(db);
  if (idx < 0) {
    return hp_strdup("");
  }
  Backup *backup = &db->backups[idx];
  for (size_t i = 0; i < backup->field_len; i++) {
    BackupField *item = &backup->fields[i];
    int64_t expiry = 0;
    if (item->has_expiry) {
      expiry = timestamp + item->expiry_delta;
    }
    set_internal(db, item->key, item->name, item->value, item->has_expiry, expiry);
  }
  return hp_strdup("");
}

static JsonVal *db_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  InMemoryDatabase *db = (InMemoryDatabase *)self;
  char *text = NULL;
  if (strcmp(method, "set") == 0) {
    set_internal(db, arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), 0, 0);
    text = hp_strdup("");
  } else if (strcmp(method, "get") == 0) {
    text = hp_strdup(get_value(db, arg_str(args, 0), arg_str(args, 1)));
  } else if (strcmp(method, "delete") == 0) {
    text = hp_strdup(delete_field(db, arg_str(args, 0), arg_str(args, 1)) ? "true" : "false");
  } else if (strcmp(method, "scan") == 0) {
    text = scan_key(db, arg_str(args, 0), NULL, 0, 0);
  } else if (strcmp(method, "scan_by_prefix") == 0) {
    text = scan_key(db, arg_str(args, 0), arg_str(args, 1), 0, 0);
  } else if (strcmp(method, "set_at") == 0) {
    set_internal(db, arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), 0, 0);
    text = hp_strdup("");
  } else if (strcmp(method, "set_at_with_ttl") == 0) {
    int64_t expiry = arg_i64(args, 3) + arg_i64(args, 4);
    set_internal(db, arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), 1, expiry);
    text = hp_strdup("");
  } else if (strcmp(method, "delete_at") == 0) {
    const char *key = arg_str(args, 0);
    const char *field = arg_str(args, 1);
    int64_t timestamp = arg_i64(args, 2);
    if (!is_alive(db, key, field, timestamp)) {
      text = hp_strdup("false");
    } else {
      delete_field(db, key, field);
      text = hp_strdup("true");
    }
  } else if (strcmp(method, "get_at") == 0) {
    const char *key = arg_str(args, 0);
    const char *field = arg_str(args, 1);
    int64_t timestamp = arg_i64(args, 2);
    if (!is_alive(db, key, field, timestamp)) {
      text = hp_strdup("");
    } else {
      text = hp_strdup(get_value(db, key, field));
    }
  } else if (strcmp(method, "scan_at") == 0) {
    text = scan_key(db, arg_str(args, 0), NULL, 1, arg_i64(args, 1));
  } else if (strcmp(method, "scan_by_prefix_at") == 0) {
    text = scan_key(db, arg_str(args, 0), arg_str(args, 1), 1, arg_i64(args, 2));
  } else if (strcmp(method, "backup") == 0) {
    text = do_backup(db, arg_i64(args, 0));
  } else if (strcmp(method, "restore") == 0) {
    text = do_restore(db, arg_i64(args, 0), arg_i64(args, 1));
  } else {
    char buf[128];
    snprintf(buf, sizeof(buf), "missing method %s", method);
    honepad_throw(buf);
  }
  JsonVal *out = json_str(text);
  free(text);
  return out;
}

static void db_free(HonepadTarget *self) {
  InMemoryDatabase *db = (InMemoryDatabase *)self;
  clear_db(db);
  for (size_t i = 0; i < db->backup_len; i++) {
    for (size_t j = 0; j < db->backups[i].field_len; j++) {
      free(db->backups[i].fields[j].key);
      free(db->backups[i].fields[j].name);
      free(db->backups[i].fields[j].value);
    }
    free(db->backups[i].fields);
  }
  free(db->backups);
  free(db);
}

static HonepadTarget *InMemoryDatabase_new(void) {
  InMemoryDatabase *db = calloc(1, sizeof(*db));
  if (db == NULL) {
    fprintf(stderr, "oom\n");
    exit(2);
  }
  db->base.call = db_call;
  db->base.free_fn = db_free;
  return &db->base;
}

#endif
