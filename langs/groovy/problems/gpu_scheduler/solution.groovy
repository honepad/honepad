class Gpu {
    String gpuId
    long mem
    String jobId = null
}

class Job {
    String jobId
    long mem
    long seq
    long priority = 0
    String state = 'queued'
    String gpuId = null
}

class Simulation {
    private final Map<String, Gpu> gpus = new LinkedHashMap<>()
    private final List<String> gpuOrder = []
    private final Map<String, Job> jobs = new LinkedHashMap<>()
    private long nextSeq = 0

    String addGpu(String gpuId, long mem) {
        if (mem <= 0) {
            return 'invalid_request'
        }
        if (gpus.containsKey(gpuId)) {
            return 'false'
        }
        gpus[gpuId] = new Gpu(gpuId: gpuId, mem: mem)
        gpuOrder.add(gpuId)
        return 'true'
    }

    String submitJob(String jobId, long mem) {
        if (mem <= 0) {
            return 'invalid_request'
        }
        if (jobs.containsKey(jobId)) {
            return 'false'
        }
        jobs[jobId] = new Job(jobId: jobId, mem: mem, seq: nextSeq)
        nextSeq += 1
        return 'true'
    }

    String status(String jobId) {
        Job job = jobs[jobId]
        return job == null ? '' : job.state
    }

    String assign() {
        List<Job> queued = jobs.values().findAll { it.state == 'queued' }
        queued.sort { a, b -> b.priority <=> a.priority ?: a.seq <=> b.seq }
        for (Job job : queued) {
            for (String gpuId : gpuOrder) {
                Gpu gpu = gpus[gpuId]
                if (gpu.jobId == null && gpu.mem >= job.mem) {
                    place(job, gpu)
                    return job.jobId
                }
            }
        }
        return ''
    }

    String complete(String jobId) {
        Job job = jobs[jobId]
        if (job == null || job.state != 'running' || job.gpuId == null) {
            return 'invalid_request'
        }
        gpus[job.gpuId].jobId = null
        job.gpuId = null
        job.state = 'done'
        return 'true'
    }

    String cancel(String jobId) {
        Job job = jobs[jobId]
        if (job == null || job.state == 'done') {
            return 'invalid_request'
        }
        if (job.state == 'running' && job.gpuId != null) {
            gpus[job.gpuId].jobId = null
        }
        jobs.remove(jobId)
        if (job.state == 'running') {
            assign()
        }
        return 'true'
    }

    String setPriority(String jobId, long priority) {
        Job job = jobs[jobId]
        if (job == null || job.state != 'queued') {
            return 'invalid_request'
        }
        job.priority = priority
        return 'true'
    }

    private void place(Job job, Gpu gpu) {
        job.state = 'running'
        job.gpuId = gpu.gpuId
        gpu.jobId = job.jobId
    }
}
