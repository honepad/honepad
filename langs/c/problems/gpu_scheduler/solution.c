#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.h"

#include <stdint.h>

typedef struct {
  char *gpu_id;
  int64_t mem;
  char *job_id;
} Gpu;

typedef struct {
  char *job_id;
  int64_t mem;
  int64_t seq;
  int64_t priority;
  const char *state;
  char *gpu_id;
} Job;

typedef struct {
  HonepadTarget base;
  Gpu *gpus;
  size_t gpu_len;
  size_t gpu_cap;
  Job *jobs;
  size_t job_len;
  size_t job_cap;
  int64_t next_seq;
} Simulation;

static Gpu *find_gpu(Simulation *sim, const char *gpu_id) {
  for (size_t i = 0; i < sim->gpu_len; i++) {
    if (strcmp(sim->gpus[i].gpu_id, gpu_id) == 0) {
      return &sim->gpus[i];
    }
  }
  return NULL;
}

static Job *find_job(Simulation *sim, const char *job_id) {
  for (size_t i = 0; i < sim->job_len; i++) {
    if (strcmp(sim->jobs[i].job_id, job_id) == 0) {
      return &sim->jobs[i];
    }
  }
  return NULL;
}

static char *add_gpu(Simulation *sim, const char *gpu_id, int64_t mem) {
  if (mem <= 0) {
    return hp_strdup("invalid_request");
  }
  if (find_gpu(sim, gpu_id) != NULL) {
    return hp_strdup("false");
  }
  HP_GROW(sim->gpus, sim->gpu_len, sim->gpu_cap, Gpu);
  sim->gpus[sim->gpu_len].gpu_id = hp_strdup(gpu_id);
  sim->gpus[sim->gpu_len].mem = mem;
  sim->gpus[sim->gpu_len].job_id = NULL;
  sim->gpu_len++;
  return hp_strdup("true");
}

static char *submit_job(Simulation *sim, const char *job_id, int64_t mem) {
  if (mem <= 0) {
    return hp_strdup("invalid_request");
  }
  if (find_job(sim, job_id) != NULL) {
    return hp_strdup("false");
  }
  HP_GROW(sim->jobs, sim->job_len, sim->job_cap, Job);
  sim->jobs[sim->job_len].job_id = hp_strdup(job_id);
  sim->jobs[sim->job_len].mem = mem;
  sim->jobs[sim->job_len].seq = sim->next_seq;
  sim->jobs[sim->job_len].priority = 0;
  sim->jobs[sim->job_len].state = "queued";
  sim->jobs[sim->job_len].gpu_id = NULL;
  sim->job_len++;
  sim->next_seq++;
  return hp_strdup("true");
}

static char *status_job(Simulation *sim, const char *job_id) {
  Job *job = find_job(sim, job_id);
  if (job == NULL) {
    return hp_strdup("");
  }
  return hp_strdup(job->state);
}

static void place(Job *job, Gpu *gpu) {
  job->state = "running";
  free(job->gpu_id);
  job->gpu_id = hp_strdup(gpu->gpu_id);
  free(gpu->job_id);
  gpu->job_id = hp_strdup(job->job_id);
}

static int cmp_queued(const void *a, const void *b) {
  const Job *left = *(const Job *const *)a;
  const Job *right = *(const Job *const *)b;
  if (left->priority != right->priority) {
    return left->priority > right->priority ? -1 : 1;
  }
  if (left->seq != right->seq) {
    return left->seq < right->seq ? -1 : 1;
  }
  return 0;
}

static char *assign(Simulation *sim) {
  Job **queued = NULL;
  size_t qlen = 0;
  size_t qcap = 0;
  for (size_t i = 0; i < sim->job_len; i++) {
    if (strcmp(sim->jobs[i].state, "queued") == 0) {
      HP_GROW(queued, qlen, qcap, Job *);
      queued[qlen++] = &sim->jobs[i];
    }
  }
  if (qlen > 0) {
    qsort(queued, qlen, sizeof(*queued), cmp_queued);
  }
  for (size_t i = 0; i < qlen; i++) {
    Job *job = queued[i];
    for (size_t g = 0; g < sim->gpu_len; g++) {
      Gpu *gpu = &sim->gpus[g];
      if (gpu->job_id == NULL && gpu->mem >= job->mem) {
        place(job, gpu);
        char *out = hp_strdup(job->job_id);
        free(queued);
        return out;
      }
    }
  }
  free(queued);
  return hp_strdup("");
}

static char *complete(Simulation *sim, const char *job_id) {
  Job *job = find_job(sim, job_id);
  if (job == NULL || strcmp(job->state, "running") != 0 || job->gpu_id == NULL) {
    return hp_strdup("invalid_request");
  }
  Gpu *gpu = find_gpu(sim, job->gpu_id);
  if (gpu != NULL) {
    free(gpu->job_id);
    gpu->job_id = NULL;
  }
  free(job->gpu_id);
  job->gpu_id = NULL;
  job->state = "done";
  return hp_strdup("true");
}

static void remove_job(Simulation *sim, Job *job) {
  size_t idx = (size_t)(job - sim->jobs);
  free(sim->jobs[idx].job_id);
  free(sim->jobs[idx].gpu_id);
  sim->jobs[idx] = sim->jobs[sim->job_len - 1];
  sim->job_len--;
}

static char *cancel(Simulation *sim, const char *job_id) {
  Job *job = find_job(sim, job_id);
  if (job == NULL || strcmp(job->state, "done") == 0) {
    return hp_strdup("invalid_request");
  }
  int running = strcmp(job->state, "running") == 0;
  if (running && job->gpu_id != NULL) {
    Gpu *gpu = find_gpu(sim, job->gpu_id);
    if (gpu != NULL) {
      free(gpu->job_id);
      gpu->job_id = NULL;
    }
  }
  remove_job(sim, job);
  if (running) {
    char *ignored = assign(sim);
    free(ignored);
  }
  return hp_strdup("true");
}

static char *set_priority(Simulation *sim, const char *job_id, int64_t priority) {
  Job *job = find_job(sim, job_id);
  if (job == NULL || strcmp(job->state, "queued") != 0) {
    return hp_strdup("invalid_request");
  }
  job->priority = priority;
  return hp_strdup("true");
}

static JsonVal *simulation_call(HonepadTarget *self, const char *method, const JsonVal *args) {
  Simulation *sim = (Simulation *)self;
  char *text = NULL;
  if (strcmp(method, "add_gpu") == 0) {
    text = add_gpu(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "submit_job") == 0) {
    text = submit_job(sim, arg_str(args, 0), arg_i64(args, 1));
  } else if (strcmp(method, "status") == 0) {
    text = status_job(sim, arg_str(args, 0));
  } else if (strcmp(method, "assign") == 0) {
    text = assign(sim);
  } else if (strcmp(method, "complete") == 0) {
    text = complete(sim, arg_str(args, 0));
  } else if (strcmp(method, "cancel") == 0) {
    text = cancel(sim, arg_str(args, 0));
  } else if (strcmp(method, "set_priority") == 0) {
    text = set_priority(sim, arg_str(args, 0), arg_i64(args, 1));
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
  for (size_t i = 0; i < sim->gpu_len; i++) {
    free(sim->gpus[i].gpu_id);
    free(sim->gpus[i].job_id);
  }
  for (size_t i = 0; i < sim->job_len; i++) {
    free(sim->jobs[i].job_id);
    free(sim->jobs[i].gpu_id);
  }
  free(sim->gpus);
  free(sim->jobs);
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
