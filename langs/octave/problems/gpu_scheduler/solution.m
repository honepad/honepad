function obj = Simulation()
  gpus = containers.Map();
  gpu_order = {};
  jobs = containers.Map();
  next_seq = 0;

  obj.add_gpu = @add_gpu;
  obj.submit_job = @submit_job;
  obj.status = @status;
  obj.assign = @assign;
  obj.complete = @complete;
  obj.cancel = @cancel;
  obj.set_priority = @set_priority;

  function result = add_gpu(gpu_id, mem)
    if (mem <= 0)
      result = "invalid_request";
      return;
    endif
    if (gpus.isKey(gpu_id))
      result = "false";
      return;
    endif
    item.gpu_id = gpu_id;
    item.mem = mem;
    item.job_id = "";
    gpus(gpu_id) = item;
    gpu_order{end + 1} = gpu_id;
    result = "true";
  endfunction

  function result = submit_job(job_id, mem)
    if (mem <= 0)
      result = "invalid_request";
      return;
    endif
    if (jobs.isKey(job_id))
      result = "false";
      return;
    endif
    item.job_id = job_id;
    item.mem = mem;
    item.seq = next_seq;
    item.priority = 0;
    item.state = "queued";
    item.gpu_id = "";
    jobs(job_id) = item;
    next_seq += 1;
    result = "true";
  endfunction

  function result = status(job_id)
    if (!jobs.isKey(job_id))
      result = "";
      return;
    endif
    item = jobs(job_id);
    result = item.state;
  endfunction

  function result = assign()
    queued = {};
    keys = jobs.keys();
    for i = 1:numel(keys)
      job = jobs(keys{i});
      if (strcmp(job.state, "queued"))
        queued{end + 1} = job;
      endif
    endfor
    n = numel(queued);
    if (n > 0)
      pri = zeros(1, n);
      seqs = zeros(1, n);
      for i = 1:n
        pri(i) = queued{i}.priority;
        seqs(i) = queued{i}.seq;
      endfor
      [~, idx] = sortrows([-pri(:), seqs(:)]);
      queued = queued(idx);
    endif
    for i = 1:numel(queued)
      job = queued{i};
      for g = 1:numel(gpu_order)
        gpu_id = gpu_order{g};
        gpu = gpus(gpu_id);
        if (isempty(gpu.job_id) && gpu.mem >= job.mem)
          job.state = "running";
          job.gpu_id = gpu_id;
          gpu.job_id = job.job_id;
          jobs(job.job_id) = job;
          gpus(gpu_id) = gpu;
          result = job.job_id;
          return;
        endif
      endfor
    endfor
    result = "";
  endfunction

  function result = complete(job_id)
    if (!jobs.isKey(job_id))
      result = "invalid_request";
      return;
    endif
    job = jobs(job_id);
    if (!strcmp(job.state, "running") || isempty(job.gpu_id))
      result = "invalid_request";
      return;
    endif
    gpu = gpus(job.gpu_id);
    gpu.job_id = "";
    gpus(job.gpu_id) = gpu;
    job.gpu_id = "";
    job.state = "done";
    jobs(job_id) = job;
    result = "true";
  endfunction

  function result = cancel(job_id)
    if (!jobs.isKey(job_id))
      result = "invalid_request";
      return;
    endif
    job = jobs(job_id);
    if (strcmp(job.state, "done"))
      result = "invalid_request";
      return;
    endif
    was_running = strcmp(job.state, "running");
    if (was_running && !isempty(job.gpu_id))
      gpu = gpus(job.gpu_id);
      gpu.job_id = "";
      gpus(job.gpu_id) = gpu;
    endif
    remove(jobs, job_id);
    if (was_running)
      assign();
    endif
    result = "true";
  endfunction

  function result = set_priority(job_id, priority)
    if (!jobs.isKey(job_id))
      result = "invalid_request";
      return;
    endif
    job = jobs(job_id);
    if (!strcmp(job.state, "queued"))
      result = "invalid_request";
      return;
    endif
    job.priority = priority;
    jobs(job_id) = job;
    result = "true";
  endfunction
endfunction
