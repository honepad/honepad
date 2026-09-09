class Gpu {
  String gpuId;
  int mem;
  String? jobId;

  Gpu(this.gpuId, this.mem);
}

class Job {
  String jobId;
  int mem;
  int seq;
  int priority = 0;
  String state = 'queued';
  String? gpuId;

  Job(this.jobId, this.mem, this.seq);
}

class Simulation {
  final Map<String, Gpu> gpus = {};
  final List<String> gpuOrder = [];
  final Map<String, Job> jobs = {};
  int nextSeq = 0;

  String addGpu(String gpuId, int mem) {
    if (mem <= 0) {
      return 'invalid_request';
    }
    if (gpus.containsKey(gpuId)) {
      return 'false';
    }
    gpus[gpuId] = Gpu(gpuId, mem);
    gpuOrder.add(gpuId);
    return 'true';
  }

  String submitJob(String jobId, int mem) {
    if (mem <= 0) {
      return 'invalid_request';
    }
    if (jobs.containsKey(jobId)) {
      return 'false';
    }
    jobs[jobId] = Job(jobId, mem, nextSeq);
    nextSeq += 1;
    return 'true';
  }

  String status(String jobId) {
    final job = jobs[jobId];
    return job == null ? '' : job.state;
  }

  String assign() {
    final queued = jobs.values.where((job) => job.state == 'queued').toList();
    queued.sort((a, b) {
      final pri = b.priority.compareTo(a.priority);
      return pri != 0 ? pri : a.seq.compareTo(b.seq);
    });
    for (final job in queued) {
      for (final gpuId in gpuOrder) {
        final gpu = gpus[gpuId]!;
        if (gpu.jobId == null && gpu.mem >= job.mem) {
          place(job, gpu);
          return job.jobId;
        }
      }
    }
    return '';
  }

  String complete(String jobId) {
    final job = jobs[jobId];
    if (job == null || job.state != 'running' || job.gpuId == null) {
      return 'invalid_request';
    }
    gpus[job.gpuId]!.jobId = null;
    job.gpuId = null;
    job.state = 'done';
    return 'true';
  }

  String cancel(String jobId) {
    final job = jobs[jobId];
    if (job == null || job.state == 'done') {
      return 'invalid_request';
    }
    if (job.state == 'running' && job.gpuId != null) {
      gpus[job.gpuId]!.jobId = null;
    }
    jobs.remove(jobId);
    if (job.state == 'running') {
      assign();
    }
    return 'true';
  }

  String setPriority(String jobId, int priority) {
    final job = jobs[jobId];
    if (job == null || job.state != 'queued') {
      return 'invalid_request';
    }
    job.priority = priority;
    return 'true';
  }

  void place(Job job, Gpu gpu) {
    job.state = 'running';
    job.gpuId = gpu.gpuId;
    gpu.jobId = job.jobId;
  }
}
