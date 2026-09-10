#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *topic;
  char **clients;
  size_t client_len;
  size_t client_cap;
} Topic;

typedef struct {
  char *client;
  char **msgs;
  size_t msg_len;
  size_t msg_cap;
} Inbox;

typedef struct {
  char *topic;
  char *message;
} Retained;

typedef struct {
  HonepadTarget base;
  Topic *topics;
  size_t topic_len;
  size_t topic_cap;
  Inbox *inboxes;
  size_t inbox_len;
  size_t inbox_cap;
  Retained *retained;
  size_t retain_len;
  size_t retain_cap;
} Simulation;

static char *fmt_i64(int64_t n) {
  char buf[32];
  snprintf(buf, sizeof(buf), "%lld", (long long)n);
  return hp_strdup(buf);
}

static char *join_parts(char **parts, size_t n) {
  size_t cap = 1;
  for (size_t i = 0; i < n; i++) {
    cap += strlen(parts[i]) + 2;
  }
  char *out = malloc(cap);
  if (out == NULL) {
    honepad_throw("oom");
  }
  out[0] = '\0';
  for (size_t i = 0; i < n; i++) {
    if (i > 0) {
      strcat(out, ", ");
    }
    strcat(out, parts[i]);
  }
  return out;
}

static Topic *find_topic(Simulation *sim, const char *topic) {
  for (size_t i = 0; i < sim->topic_len; i++) {
    if (strcmp(sim->topics[i].topic, topic) == 0) {
      return &sim->topics[i];
    }
  }
  return NULL;
}

static Inbox *find_inbox(Simulation *sim, const char *client) {
  for (size_t i = 0; i < sim->inbox_len; i++) {
    if (strcmp(sim->inboxes[i].client, client) == 0) {
      return &sim->inboxes[i];
    }
  }
  return NULL;
}

static Inbox *ensure_inbox(Simulation *sim, const char *client) {
  Inbox *box = find_inbox(sim, client);
  if (box != NULL) {
    return box;
  }
  HP_GROW(sim->inboxes, sim->inbox_len, sim->inbox_cap, Inbox);
  box = &sim->inboxes[sim->inbox_len++];
  box->client = hp_strdup(client);
  box->msgs = NULL;
  box->msg_len = 0;
  box->msg_cap = 0;
  return box;
}

static const char *find_retained(Simulation *sim, const char *topic) {
  for (size_t i = 0; i < sim->retain_len; i++) {
    if (strcmp(sim->retained[i].topic, topic) == 0) {
      return sim->retained[i].message;
    }
  }
  return NULL;
}

static int cmp_cstr(const void *a, const void *b) {
  return strcmp(*(const char *const *)a, *(const char *const *)b);
}

static char *subscribe(Simulation *sim, const char *topic, const char *client) {
  Topic *row = find_topic(sim, topic);
  if (row != NULL) {
    for (size_t i = 0; i < row->client_len; i++) {
      if (strcmp(row->clients[i], client) == 0) {
        return hp_strdup("false");
      }
    }
  } else {
    HP_GROW(sim->topics, sim->topic_len, sim->topic_cap, Topic);
    row = &sim->topics[sim->topic_len++];
    row->topic = hp_strdup(topic);
    row->clients = NULL;
    row->client_len = 0;
    row->client_cap = 0;
  }
  HP_GROW(row->clients, row->client_len, row->client_cap, char *);
  row->clients[row->client_len++] = hp_strdup(client);
  const char *kept = find_retained(sim, topic);
  if (kept != NULL) {
    Inbox *box = ensure_inbox(sim, client);
    size_t n = strlen(topic) + strlen(kept) + 2;
    char *payload = malloc(n);
    if (payload == NULL) {
      honepad_throw("oom");
    }
    snprintf(payload, n, "%s:%s", topic, kept);
    HP_GROW(box->msgs, box->msg_len, box->msg_cap, char *);
    box->msgs[box->msg_len++] = payload;
  }
  return hp_strdup("true");
}

static char *unsubscribe(Simulation *sim, const char *topic, const char *client) {
  Topic *row = find_topic(sim, topic);
  if (row == NULL) {
    return hp_strdup("false");
  }
  size_t idx = (size_t)-1;
  for (size_t i = 0; i < row->client_len; i++) {
    if (strcmp(row->clients[i], client) == 0) {
      idx = i;
      break;
    }
  }
  if (idx == (size_t)-1) {
    return hp_strdup("false");
  }
  free(row->clients[idx]);
  for (size_t i = idx + 1; i < row->client_len; i++) {
    row->clients[i - 1] = row->clients[i];
  }
  row->client_len--;
  if (row->client_len == 0) {
    size_t tidx = (size_t)(row - sim->topics);
    free(row->topic);
    free(row->clients);
    for (size_t i = tidx + 1; i < sim->topic_len; i++) {
      sim->topics[i - 1] = sim->topics[i];
    }
    sim->topic_len--;
  }
  return hp_strdup("true");
}

static char *publish(Simulation *sim, const char *topic, const char *message) {
  Topic *row = find_topic(sim, topic);
  if (row == NULL) {
    return hp_strdup("0");
  }
  size_t n = strlen(topic) + strlen(message) + 2;
  for (size_t i = 0; i < row->client_len; i++) {
    char *payload = malloc(n);
    if (payload == NULL) {
      honepad_throw("oom");
    }
    snprintf(payload, n, "%s:%s", topic, message);
    Inbox *box = ensure_inbox(sim, row->clients[i]);
    HP_GROW(box->msgs, box->msg_len, box->msg_cap, char *);
    box->msgs[box->msg_len++] = payload;
  }
  return fmt_i64((int64_t)row->client_len);
}

static char *inbox(Simulation *sim, const char *client) {
  Inbox *box = find_inbox(sim, client);
  if (box == NULL) {
    return hp_strdup("");
  }
  return join_parts(box->msgs, box->msg_len);
}

static char *list_topics(Simulation *sim) {
  char **parts = NULL;
  size_t n = sim->topic_len;
  if (n > 0) {
    parts = malloc(n * sizeof(*parts));
    if (parts == NULL) {
      honepad_throw("oom");
    }
    for (size_t i = 0; i < n; i++) {
      parts[i] = sim->topics[i].topic;
    }
    qsort(parts, n, sizeof(*parts), cmp_cstr);
  }
  char *out = join_parts(parts, n);
  free(parts);
  return out;
}

static char *subscribers(Simulation *sim, const char *topic) {
  Topic *row = find_topic(sim, topic);
  if (row == NULL) {
    return hp_strdup("");
  }
  char **parts = NULL;
  if (row->client_len > 0) {
    parts = malloc(row->client_len * sizeof(*parts));
    if (parts == NULL) {
      honepad_throw("oom");
    }
    for (size_t i = 0; i < row->client_len; i++) {
      parts[i] = row->clients[i];
    }
    qsort(parts, row->client_len, sizeof(*parts), cmp_cstr);
  }
  char *out = join_parts(parts, row->client_len);
  free(parts);
  return out;
}

static char *peek(Simulation *sim, const char *client) {
  Inbox *box = find_inbox(sim, client);
  if (box == NULL || box->msg_len == 0) {
    return hp_strdup("");
  }
  return hp_strdup(box->msgs[0]);
}

static char *ack(Simulation *sim, const char *client, int64_t n) {
  Inbox *box = find_inbox(sim, client);
  if (n <= 0 || box == NULL) {
    return hp_strdup("invalid_request");
  }
  if (n > (int64_t)box->msg_len) {
    return hp_strdup("invalid_request");
  }
  for (int64_t i = 0; i < n; i++) {
    free(box->msgs[i]);
  }
  for (size_t i = (size_t)n; i < box->msg_len; i++) {
    box->msgs[i - (size_t)n] = box->msgs[i];
  }
  box->msg_len -= (size_t)n;
  return fmt_i64((int64_t)box->msg_len);
}

static char *retain(Simulation *sim, const char *topic, const char *message) {
  for (size_t i = 0; i < sim->retain_len; i++) {
    if (strcmp(sim->retained[i].topic, topic) == 0) {
      free(sim->retained[i].message);
      sim->retained[i].message = hp_strdup(message);
      return hp_strdup("");
    }
  }
  HP_GROW(sim->retained, sim->retain_len, sim->retain_cap, Retained);
  sim->retained[sim->retain_len].topic = hp_strdup(topic);
  sim->retained[sim->retain_len].message = hp_strdup(message);
  sim->retain_len++;
  return hp_strdup("");
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "subscribe") == 0) {
    text = subscribe(sim, arg_str(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "unsubscribe") == 0) {
    text = unsubscribe(sim, arg_str(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "publish") == 0) {
    text = publish(sim, arg_str(args, 0), arg_str(args, 1));
  } else if (strcmp(method, "inbox") == 0) {
    text = inbox(sim, arg_str(args, 0));
  } else if (strcmp(method, "list_topics") == 0) {
    text = list_topics(sim);
  } else if (strcmp(method, "subscribers") == 0) {
    text = subscribers(sim, arg_str(args, 0));
  } else if (strcmp(method, "peek") == 0) {
    text = peek(sim, arg_str(args, 0));
  } else if (strcmp(method, "ack") == 0) {
    text = ack(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "retain") == 0) {
    text = retain(sim, arg_str(args, 0), arg_str(args, 1));
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
  for (size_t i = 0; i < sim->topic_len; i++) {
    for (size_t j = 0; j < sim->topics[i].client_len; j++) {
      free(sim->topics[i].clients[j]);
    }
    free(sim->topics[i].clients);
    free(sim->topics[i].topic);
  }
  free(sim->topics);
  for (size_t i = 0; i < sim->inbox_len; i++) {
    for (size_t j = 0; j < sim->inboxes[i].msg_len; j++) {
      free(sim->inboxes[i].msgs[j]);
    }
    free(sim->inboxes[i].msgs);
    free(sim->inboxes[i].client);
  }
  free(sim->inboxes);
  for (size_t i = 0; i < sim->retain_len; i++) {
    free(sim->retained[i].topic);
    free(sim->retained[i].message);
  }
  free(sim->retained);
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
