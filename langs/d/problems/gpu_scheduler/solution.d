import std.algorithm : sort;

class Gpu
{
    string gpuId;
    long mem;
    string jobId;

    this(string gpuId, long mem)
    {
        this.gpuId = gpuId;
        this.mem = mem;
    }
}

class Job
{
    string jobId;
    long mem;
    long seq;
    long priority;
    string state = "queued";
    string gpuId;

    this(string jobId, long mem, long seq)
    {
        this.jobId = jobId;
        this.mem = mem;
        this.seq = seq;
    }
}

class Simulation
{
    Gpu[string] gpus;
    string[] gpuOrder;
    Job[string] jobs;
    long nextSeq;

    string addGpu(string gpuId, long mem)
    {
        if (mem <= 0)
        {
            return "invalid_request";
        }
        if (gpuId in gpus)
        {
            return "false";
        }
        gpus[gpuId] = new Gpu(gpuId, mem);
        gpuOrder ~= gpuId;
        return "true";
    }

    string submitJob(string jobId, long mem)
    {
        if (mem <= 0)
        {
            return "invalid_request";
        }
        if (jobId in jobs)
        {
            return "false";
        }
        jobs[jobId] = new Job(jobId, mem, nextSeq);
        nextSeq += 1;
        return "true";
    }

    string status(string jobId)
    {
        if (jobId !in jobs)
        {
            return "";
        }
        return jobs[jobId].state;
    }

    private void place(Job job, Gpu gpu)
    {
        job.state = "running";
        job.gpuId = gpu.gpuId;
        gpu.jobId = job.jobId;
    }

    string assign()
    {
        Job[] queued;
        foreach (job; jobs.byValue)
        {
            if (job.state == "queued")
            {
                queued ~= job;
            }
        }
        queued.sort!((a, b) {
            if (a.priority != b.priority)
            {
                return a.priority > b.priority;
            }
            return a.seq < b.seq;
        });
        foreach (job; queued)
        {
            foreach (gpuId; gpuOrder)
            {
                auto gpu = gpus[gpuId];
                if (gpu.jobId.length == 0 && gpu.mem >= job.mem)
                {
                    place(job, gpu);
                    return job.jobId;
                }
            }
        }
        return "";
    }

    string complete(string jobId)
    {
        if (jobId !in jobs)
        {
            return "invalid_request";
        }
        auto job = jobs[jobId];
        if (job.state != "running" || job.gpuId.length == 0)
        {
            return "invalid_request";
        }
        gpus[job.gpuId].jobId = "";
        job.gpuId = "";
        job.state = "done";
        return "true";
    }

    string cancel(string jobId)
    {
        if (jobId !in jobs)
        {
            return "invalid_request";
        }
        auto job = jobs[jobId];
        if (job.state == "done")
        {
            return "invalid_request";
        }
        const running = job.state == "running";
        if (running && job.gpuId.length > 0)
        {
            gpus[job.gpuId].jobId = "";
        }
        jobs.remove(jobId);
        if (running)
        {
            assign();
        }
        return "true";
    }

    string setPriority(string jobId, long priority)
    {
        if (jobId !in jobs)
        {
            return "invalid_request";
        }
        auto job = jobs[jobId];
        if (job.state != "queued")
        {
            return "invalid_request";
        }
        job.priority = priority;
        return "true";
    }
}
