import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class Gpu {
    String gpuId;
    int mem;
    String jobId;

    Gpu(String gpuId, int mem) {
        this.gpuId = gpuId;
        this.mem = mem;
    }
}

class Job {
    String jobId;
    int mem;
    int seq;
    int priority = 0;
    String state = "queued";
    String gpuId;

    Job(String jobId, int mem, int seq) {
        this.jobId = jobId;
        this.mem = mem;
        this.seq = seq;
    }
}

public class Simulation {
    private final Map<String, Gpu> gpus = new HashMap<>();
    private final List<String> gpuOrder = new ArrayList<>();
    private final Map<String, Job> jobs = new HashMap<>();
    private int nextSeq = 0;

    public Simulation() {}

    public String addGpu(String gpuId, int mem) {
        if (mem <= 0) {
            return "invalid_request";
        }
        if (gpus.containsKey(gpuId)) {
            return "false";
        }
        gpus.put(gpuId, new Gpu(gpuId, mem));
        gpuOrder.add(gpuId);
        return "true";
    }

    public String submitJob(String jobId, int mem) {
        if (mem <= 0) {
            return "invalid_request";
        }
        if (jobs.containsKey(jobId)) {
            return "false";
        }
        jobs.put(jobId, new Job(jobId, mem, nextSeq));
        nextSeq += 1;
        return "true";
    }

    public String status(String jobId) {
        Job job = jobs.get(jobId);
        if (job == null) {
            return "";
        }
        return job.state;
    }

    private void place(Job job, Gpu gpu) {
        job.state = "running";
        job.gpuId = gpu.gpuId;
        gpu.jobId = job.jobId;
    }

    public String assign() {
        List<Job> queued = new ArrayList<>();
        for (Job job : jobs.values()) {
            if ("queued".equals(job.state)) {
                queued.add(job);
            }
        }
        queued.sort((a, b) -> {
            if (a.priority != b.priority) {
                return Integer.compare(b.priority, a.priority);
            }
            return Integer.compare(a.seq, b.seq);
        });
        for (Job job : queued) {
            for (String gpuId : gpuOrder) {
                Gpu gpu = gpus.get(gpuId);
                if (gpu.jobId == null && gpu.mem >= job.mem) {
                    place(job, gpu);
                    return job.jobId;
                }
            }
        }
        return "";
    }

    public String complete(String jobId) {
        Job job = jobs.get(jobId);
        if (job == null || !"running".equals(job.state) || job.gpuId == null) {
            return "invalid_request";
        }
        gpus.get(job.gpuId).jobId = null;
        job.gpuId = null;
        job.state = "done";
        return "true";
    }

    public String cancel(String jobId) {
        Job job = jobs.get(jobId);
        if (job == null || "done".equals(job.state)) {
            return "invalid_request";
        }
        boolean running = "running".equals(job.state);
        if (running && job.gpuId != null) {
            gpus.get(job.gpuId).jobId = null;
        }
        jobs.remove(jobId);
        if (running) {
            assign();
        }
        return "true";
    }

    public String setPriority(String jobId, int priority) {
        Job job = jobs.get(jobId);
        if (job == null || !"queued".equals(job.state)) {
            return "invalid_request";
        }
        job.priority = priority;
        return "true";
    }
}
