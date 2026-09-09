#ifndef HONEPAD_SOLUTION_INCLUDED
#define HONEPAD_SOLUTION_INCLUDED

#include "harness.hpp"

#include <algorithm>
#include <map>
#include <string>
#include <vector>

class Gpu {
 public:
  std::string gpu_id;
  int64_t mem = 0;
  std::string job_id;
};

class Job {
 public:
  std::string job_id;
  int64_t mem = 0;
  int64_t seq = 0;
  int64_t priority = 0;
  std::string state = "queued";
  std::string gpu_id;
};

class Simulation : public Harness {
  std::map<std::string, Gpu> gpus;
  std::vector<std::string> gpu_order;
  std::map<std::string, Job> jobs;
  int64_t next_seq = 0;

  std::string add_gpu(const std::string& gpu_id, int64_t mem) {
    if (mem <= 0) {
      return "invalid_request";
    }
    if (gpus.count(gpu_id) != 0) {
      return "false";
    }
    Gpu gpu;
    gpu.gpu_id = gpu_id;
    gpu.mem = mem;
    gpus[gpu_id] = gpu;
    gpu_order.push_back(gpu_id);
    return "true";
  }

  std::string submit_job(const std::string& job_id, int64_t mem) {
    if (mem <= 0) {
      return "invalid_request";
    }
    if (jobs.count(job_id) != 0) {
      return "false";
    }
    Job job;
    job.job_id = job_id;
    job.mem = mem;
    job.seq = next_seq;
    jobs[job_id] = job;
    next_seq += 1;
    return "true";
  }

  std::string status(const std::string& job_id) const {
    auto it = jobs.find(job_id);
    if (it == jobs.end()) {
      return "";
    }
    return it->second.state;
  }

  void place(Job& job, Gpu& gpu) {
    job.state = "running";
    job.gpu_id = gpu.gpu_id;
    gpu.job_id = job.job_id;
  }

  std::string assign() {
    std::vector<Job*> queued;
    for (auto& entry : jobs) {
      if (entry.second.state == "queued") {
        queued.push_back(&entry.second);
      }
    }
    std::sort(queued.begin(), queued.end(), [](const Job* a, const Job* b) {
      if (a->priority != b->priority) {
        return a->priority > b->priority;
      }
      return a->seq < b->seq;
    });
    for (Job* job : queued) {
      for (const std::string& gpu_id : gpu_order) {
        Gpu& gpu = gpus[gpu_id];
        if (gpu.job_id.empty() && gpu.mem >= job->mem) {
          place(*job, gpu);
          return job->job_id;
        }
      }
    }
    return "";
  }

  std::string complete(const std::string& job_id) {
    auto it = jobs.find(job_id);
    if (it == jobs.end() || it->second.state != "running" || it->second.gpu_id.empty()) {
      return "invalid_request";
    }
    gpus[it->second.gpu_id].job_id.clear();
    it->second.gpu_id.clear();
    it->second.state = "done";
    return "true";
  }

  std::string cancel(const std::string& job_id) {
    auto it = jobs.find(job_id);
    if (it == jobs.end() || it->second.state == "done") {
      return "invalid_request";
    }
    bool running = it->second.state == "running";
    if (running && !it->second.gpu_id.empty()) {
      gpus[it->second.gpu_id].job_id.clear();
    }
    jobs.erase(it);
    if (running) {
      assign();
    }
    return "true";
  }

  std::string set_priority(const std::string& job_id, int64_t priority) {
    auto it = jobs.find(job_id);
    if (it == jobs.end() || it->second.state != "queued") {
      return "invalid_request";
    }
    it->second.priority = priority;
    return "true";
  }

 public:
  JsonVal call(const std::string& method, const std::vector<JsonVal>& args) override {
    std::string text;
    if (method == "addGpu") {
      text = add_gpu(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "submitJob") {
      text = submit_job(arg_str(args, 0), arg_i64(args, 1));
    } else if (method == "status") {
      text = status(arg_str(args, 0));
    } else if (method == "assign") {
      text = assign();
    } else if (method == "complete") {
      text = complete(arg_str(args, 0));
    } else if (method == "cancel") {
      text = cancel(arg_str(args, 0));
    } else if (method == "setPriority") {
      text = set_priority(arg_str(args, 0), arg_i64(args, 1));
    } else {
      throw std::runtime_error("missing method " + method);
    }
    return JsonVal::from_str(text);
  }
};

#endif
