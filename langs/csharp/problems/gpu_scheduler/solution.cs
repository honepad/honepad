class Gpu
{
    public string GpuId;
    public int Mem;
    public string? JobId;

    public Gpu(string gpuId, int mem)
    {
        GpuId = gpuId;
        Mem = mem;
    }
}

class Job
{
    public string JobId;
    public int Mem;
    public int Seq;
    public int Priority;
    public string State = "queued";
    public string? GpuId;

    public Job(string jobId, int mem, int seq)
    {
        JobId = jobId;
        Mem = mem;
        Seq = seq;
    }
}

public class Simulation
{
    readonly Dictionary<string, Gpu> gpus = new();
    readonly List<string> gpuOrder = new();
    readonly Dictionary<string, Job> jobs = new();
    int nextSeq;

    public Simulation() { }

    public string AddGpu(string gpuId, int mem)
    {
        if (mem <= 0)
        {
            return "invalid_request";
        }
        if (gpus.ContainsKey(gpuId))
        {
            return "false";
        }
        gpus[gpuId] = new Gpu(gpuId, mem);
        gpuOrder.Add(gpuId);
        return "true";
    }

    public string SubmitJob(string jobId, int mem)
    {
        if (mem <= 0)
        {
            return "invalid_request";
        }
        if (jobs.ContainsKey(jobId))
        {
            return "false";
        }
        jobs[jobId] = new Job(jobId, mem, nextSeq);
        nextSeq += 1;
        return "true";
    }

    public string Status(string jobId)
    {
        if (!jobs.TryGetValue(jobId, out Job? job))
        {
            return "";
        }
        return job.State;
    }

    void Place(Job job, Gpu gpu)
    {
        job.State = "running";
        job.GpuId = gpu.GpuId;
        gpu.JobId = job.JobId;
    }

    public string Assign()
    {
        List<Job> queued = new();
        foreach (Job job in jobs.Values)
        {
            if (job.State == "queued")
            {
                queued.Add(job);
            }
        }
        queued.Sort((a, b) =>
        {
            int byPriority = b.Priority.CompareTo(a.Priority);
            return byPriority != 0 ? byPriority : a.Seq.CompareTo(b.Seq);
        });
        foreach (Job job in queued)
        {
            foreach (string gpuId in gpuOrder)
            {
                Gpu gpu = gpus[gpuId];
                if (gpu.JobId is null && gpu.Mem >= job.Mem)
                {
                    Place(job, gpu);
                    return job.JobId;
                }
            }
        }
        return "";
    }

    public string Complete(string jobId)
    {
        if (!jobs.TryGetValue(jobId, out Job? job) || job.State != "running" || job.GpuId is null)
        {
            return "invalid_request";
        }
        gpus[job.GpuId].JobId = null;
        job.GpuId = null;
        job.State = "done";
        return "true";
    }

    public string Cancel(string jobId)
    {
        if (!jobs.TryGetValue(jobId, out Job? job) || job.State == "done")
        {
            return "invalid_request";
        }
        bool running = job.State == "running";
        if (running && job.GpuId is not null)
        {
            gpus[job.GpuId].JobId = null;
        }
        jobs.Remove(jobId);
        if (running)
        {
            Assign();
        }
        return "true";
    }

    public string SetPriority(string jobId, int priority)
    {
        if (!jobs.TryGetValue(jobId, out Job? job) || job.State != "queued")
        {
            return "invalid_request";
        }
        job.Priority = priority;
        return "true";
    }
}
