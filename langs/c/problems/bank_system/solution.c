#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

enum { kCashbackDelay = 24LL * 60LL * 60LL * 1000LL };

typedef struct {
  int64_t timestamp;
  int64_t balance;
} BalRow;

typedef struct {
  char *id;
  char *status;
} PayRow;

typedef struct {
  char *account_id;
  int64_t balance;
  int64_t outgoing;
  PayRow *payments;
  size_t pay_len;
  size_t pay_cap;
  int64_t created_at;
  BalRow *history;
  size_t hist_len;
  size_t hist_cap;
} Account;

typedef struct {
  int64_t timestamp;
  char *account_id;
  int64_t amount;
  char *payment_id;
} Cashback;

typedef struct {
  HonepadTarget base;
  Account *accounts;
  size_t acc_len;
  size_t acc_cap;
  int64_t payment_counter;
  Cashback *pending;
  size_t pend_len;
  size_t pend_cap;
} Simulation;

static void account_free(Account *acc) {
  free(acc->account_id);
  for (size_t i = 0; i < acc->pay_len; i++) {
    free(acc->payments[i].id);
    free(acc->payments[i].status);
  }
  free(acc->payments);
  free(acc->history);
}

static Account *find_account(Simulation *sim, const char *account_id) {
  for (size_t i = 0; i < sim->acc_len; i++) {
    if (strcmp(sim->accounts[i].account_id, account_id) == 0) {
      return &sim->accounts[i];
    }
  }
  return NULL;
}

static void record_balance(Account *acc, int64_t timestamp) {
  HP_GROW(acc->history, acc->hist_len, acc->hist_cap, BalRow);
  acc->history[acc->hist_len].timestamp = timestamp;
  acc->history[acc->hist_len].balance = acc->balance;
  acc->hist_len++;
}

static void set_payment(Account *acc, const char *payment_id, const char *status) {
  for (size_t i = 0; i < acc->pay_len; i++) {
    if (strcmp(acc->payments[i].id, payment_id) == 0) {
      free(acc->payments[i].status);
      acc->payments[i].status = hp_strdup(status);
      return;
    }
  }
  HP_GROW(acc->payments, acc->pay_len, acc->pay_cap, PayRow);
  acc->payments[acc->pay_len].id = hp_strdup(payment_id);
  acc->payments[acc->pay_len].status = hp_strdup(status);
  acc->pay_len++;
}

static const char *get_payment(const Account *acc, const char *payment_id) {
  for (size_t i = 0; i < acc->pay_len; i++) {
    if (strcmp(acc->payments[i].id, payment_id) == 0) {
      return acc->payments[i].status;
    }
  }
  return NULL;
}

static void process_cashbacks(Simulation *sim, int64_t timestamp) {
  size_t i = 0;
  while (i < sim->pend_len && sim->pending[i].timestamp <= timestamp) {
    Cashback *cb = &sim->pending[i];
    Account *acc = find_account(sim, cb->account_id);
    if (acc != NULL) {
      acc->balance += cb->amount;
      set_payment(acc, cb->payment_id, "CASHBACK_RECEIVED");
      record_balance(acc, cb->timestamp);
    }
    free(cb->account_id);
    free(cb->payment_id);
    i++;
  }
  if (i > 0) {
    memmove(sim->pending, sim->pending + i, (sim->pend_len - i) * sizeof(Cashback));
    sim->pend_len -= i;
  }
}

static int create_account(Simulation *sim, int64_t timestamp, const char *account_id) {
  process_cashbacks(sim, timestamp);
  if (find_account(sim, account_id) != NULL) {
    return 0;
  }
  HP_GROW(sim->accounts, sim->acc_len, sim->acc_cap, Account);
  Account *acc = &sim->accounts[sim->acc_len++];
  memset(acc, 0, sizeof(*acc));
  acc->account_id = hp_strdup(account_id);
  acc->created_at = timestamp;
  record_balance(acc, timestamp);
  return 1;
}

static int deposit(Simulation *sim, int64_t timestamp, const char *account_id, int64_t amount, int64_t *out) {
  process_cashbacks(sim, timestamp);
  Account *acc = find_account(sim, account_id);
  if (acc == NULL) {
    return 0;
  }
  acc->balance += amount;
  record_balance(acc, timestamp);
  *out = acc->balance;
  return 1;
}

static int withdraw(Account *acc, int64_t amount) {
  if (acc->balance < amount) {
    return 0;
  }
  acc->balance -= amount;
  acc->outgoing += amount;
  return 1;
}

static int transfer(
    Simulation *sim,
    int64_t timestamp,
    const char *source_id,
    const char *target_id,
    int64_t amount,
    int64_t *out) {
  process_cashbacks(sim, timestamp);
  if (strcmp(source_id, target_id) == 0) {
    return 0;
  }
  Account *src = find_account(sim, source_id);
  Account *dst = find_account(sim, target_id);
  if (src == NULL || dst == NULL) {
    return 0;
  }
  if (!withdraw(src, amount)) {
    return 0;
  }
  dst->balance += amount;
  record_balance(src, timestamp);
  record_balance(dst, timestamp);
  *out = src->balance;
  return 1;
}

typedef struct {
  char *id;
  int64_t outgoing;
} Spend;

static int cmp_spend(const void *a, const void *b) {
  const Spend *x = a;
  const Spend *y = b;
  if (x->outgoing != y->outgoing) {
    return x->outgoing > y->outgoing ? -1 : 1;
  }
  return strcmp(x->id, y->id);
}

static JsonVal *top_spenders(Simulation *sim, int64_t timestamp, int64_t n) {
  process_cashbacks(sim, timestamp);
  Spend *rows = NULL;
  if (sim->acc_len > 0) {
    rows = malloc(sim->acc_len * sizeof(*rows));
    if (rows == NULL) {
      honepad_throw("oom");
    }
  }
  for (size_t i = 0; i < sim->acc_len; i++) {
    rows[i].id = sim->accounts[i].account_id;
    rows[i].outgoing = sim->accounts[i].outgoing;
  }
  qsort(rows, sim->acc_len, sizeof(*rows), cmp_spend);
  size_t take = sim->acc_len;
  if (n >= 0 && (size_t)n < take) {
    take = (size_t)n;
  }
  JsonVal *out = json_arr();
  for (size_t i = 0; i < take; i++) {
    char buf[128];
    snprintf(buf, sizeof(buf), "%s(%lld)", rows[i].id, (long long)rows[i].outgoing);
    json_arr_push(out, json_str(buf));
  }
  free(rows);
  return out;
}

static const char *pay(Simulation *sim, int64_t timestamp, const char *account_id, int64_t amount) {
  process_cashbacks(sim, timestamp);
  Account *acc = find_account(sim, account_id);
  if (acc == NULL || !withdraw(acc, amount)) {
    return NULL;
  }
  sim->payment_counter += 1;
  char payment_id[32];
  snprintf(payment_id, sizeof(payment_id), "payment%lld", (long long)sim->payment_counter);
  set_payment(acc, payment_id, "IN_PROGRESS");
  record_balance(acc, timestamp);
  HP_GROW(sim->pending, sim->pend_len, sim->pend_cap, Cashback);
  Cashback *cb = &sim->pending[sim->pend_len++];
  cb->timestamp = timestamp + kCashbackDelay;
  cb->account_id = hp_strdup(account_id);
  cb->amount = (amount * 2) / 100;
  cb->payment_id = hp_strdup(payment_id);
  return get_payment(acc, payment_id) ? acc->payments[acc->pay_len - 1].id : NULL;
}

static const char *get_payment_status(
    Simulation *sim, int64_t timestamp, const char *account_id, const char *payment) {
  process_cashbacks(sim, timestamp);
  Account *acc = find_account(sim, account_id);
  if (acc == NULL) {
    return NULL;
  }
  return get_payment(acc, payment);
}

static int cmp_hist(const void *a, const void *b) {
  const BalRow *x = a;
  const BalRow *y = b;
  if (x->timestamp != y->timestamp) {
    return x->timestamp < y->timestamp ? -1 : 1;
  }
  return 0;
}

static int merge_accounts(Simulation *sim, int64_t timestamp, const char *keep_id, const char *drop_id) {
  process_cashbacks(sim, timestamp);
  if (strcmp(keep_id, drop_id) == 0) {
    return 0;
  }
  Account *keep = find_account(sim, keep_id);
  Account *drop = find_account(sim, drop_id);
  if (keep == NULL || drop == NULL) {
    return 0;
  }
  keep->balance += drop->balance;
  keep->outgoing += drop->outgoing;
  for (size_t i = 0; i < drop->pay_len; i++) {
    if (get_payment(keep, drop->payments[i].id) == NULL) {
      set_payment(keep, drop->payments[i].id, drop->payments[i].status);
    }
  }
  for (size_t i = 0; i < drop->hist_len; i++) {
    HP_GROW(keep->history, keep->hist_len, keep->hist_cap, BalRow);
    keep->history[keep->hist_len++] = drop->history[i];
  }
  drop->hist_len = 0;
  drop->history = NULL;
  qsort(keep->history, keep->hist_len, sizeof(BalRow), cmp_hist);
  if (drop->created_at < keep->created_at) {
    keep->created_at = drop->created_at;
  }
  record_balance(keep, timestamp);
  for (size_t i = 0; i < sim->pend_len; i++) {
    if (strcmp(sim->pending[i].account_id, drop_id) == 0) {
      free(sim->pending[i].account_id);
      sim->pending[i].account_id = hp_strdup(keep_id);
    }
  }
  size_t idx = (size_t)(drop - sim->accounts);
  account_free(drop);
  memmove(sim->accounts + idx, sim->accounts + idx + 1, (sim->acc_len - idx - 1) * sizeof(Account));
  sim->acc_len--;
  return 1;
}

static int get_balance(Simulation *sim, int64_t timestamp, const char *account_id, int64_t time_at, int64_t *out) {
  process_cashbacks(sim, timestamp);
  Account *acc = find_account(sim, account_id);
  if (acc == NULL || time_at < acc->created_at) {
    return 0;
  }
  int found = 0;
  for (size_t i = 0; i < acc->hist_len; i++) {
    if (acc->history[i].timestamp <= time_at) {
      *out = acc->history[i].balance;
      found = 1;
    } else {
      break;
    }
  }
  return found;
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  if (strcmp(method, "create_account") == 0) {
    return json_bool(create_account(sim, arg_i64(args, 0), arg_str(args, 1)));
  }
  if (strcmp(method, "deposit") == 0) {
    int64_t value = 0;
    int ok = deposit(sim, arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2), &value);
    return opt_i64(ok, value);
  }
  if (strcmp(method, "transfer") == 0) {
    int64_t value = 0;
    int ok = transfer(sim, arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2), arg_i64(args, 3), &value);
    return opt_i64(ok, value);
  }
  if (strcmp(method, "top_spenders") == 0) {
    return top_spenders(sim, arg_i64(args, 0), arg_i64(args, 1));
  }
  if (strcmp(method, "pay") == 0) {
    return opt_str(pay(sim, arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2)));
  }
  if (strcmp(method, "get_payment_status") == 0) {
    return opt_str(get_payment_status(sim, arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2)));
  }
  if (strcmp(method, "merge_accounts") == 0) {
    return json_bool(merge_accounts(sim, arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2)));
  }
  if (strcmp(method, "get_balance") == 0) {
    int64_t value = 0;
    int ok = get_balance(sim, arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2), &value);
    return opt_i64(ok, value);
  }
  char buf[128];
  snprintf(buf, sizeof(buf), "missing method %s", method);
  honepad_throw(buf);
  return json_null();
}

static void simulation_free(HonepadTarget *self) {
  Simulation *sim = (Simulation *)self;
  for (size_t i = 0; i < sim->acc_len; i++) {
    account_free(&sim->accounts[i]);
  }
  free(sim->accounts);
  for (size_t i = 0; i < sim->pend_len; i++) {
    free(sim->pending[i].account_id);
    free(sim->pending[i].payment_id);
  }
  free(sim->pending);
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
