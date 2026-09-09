class Gpu(val gpuId: String, val mem: Int, var jobId: String? = null)

class Job(
    val jobId: String,
    val mem: Int,
    val seq: Int,
    var priority: Int = 0,
    var state: String = "queued",
    var gpuId: String? = null,
)

class Simulation {
    private val gpus = HashMap<String, Gpu>()
    private val gpuOrder = ArrayList<String>()
    private val jobs = HashMap<String, Job>()
    private var nextSeq = 0

    fun addGpu(gpuId: String, mem: Int): String {
        if (mem <= 0) {
            return "invalid_request"
        }
        if (gpus.containsKey(gpuId)) {
            return "false"
        }
        gpus[gpuId] = Gpu(gpuId, mem)
        gpuOrder.add(gpuId)
        return "true"
    }

    fun submitJob(jobId: String, mem: Int): String {
        if (mem <= 0) {
            return "invalid_request"
        }
        if (jobs.containsKey(jobId)) {
            return "false"
        }
        jobs[jobId] = Job(jobId, mem, nextSeq)
        nextSeq += 1
        return "true"
    }

    fun status(jobId: String): String {
        val job = jobs[jobId] ?: return ""
        return job.state
    }

    private fun place(job: Job, gpu: Gpu) {
        job.state = "running"
        job.gpuId = gpu.gpuId
        gpu.jobId = job.jobId
    }

    fun assign(): String {
        val queued = ArrayList<Job>()
        for (job in jobs.values) {
            if (job.state == "queued") {
                queued.add(job)
            }
        }
        queued.sortWith { a, b ->
            val byPriority = b.priority.compareTo(a.priority)
            if (byPriority != 0) byPriority else a.seq.compareTo(b.seq)
        }
        for (job in queued) {
            for (gpuId in gpuOrder) {
                val gpu = gpus[gpuId]!!
                if (gpu.jobId == null && gpu.mem >= job.mem) {
                    place(job, gpu)
                    return job.jobId
                }
            }
        }
        return ""
    }

    fun complete(jobId: String): String {
        val job = jobs[jobId]
        if (job == null || job.state != "running" || job.gpuId == null) {
            return "invalid_request"
        }
        gpus[job.gpuId]!!.jobId = null
        job.gpuId = null
        job.state = "done"
        return "true"
    }

    fun cancel(jobId: String): String {
        val job = jobs[jobId]
        if (job == null || job.state == "done") {
            return "invalid_request"
        }
        val running = job.state == "running"
        if (running && job.gpuId != null) {
            gpus[job.gpuId]!!.jobId = null
        }
        jobs.remove(jobId)
        if (running) {
            assign()
        }
        return "true"
    }

    fun setPriority(jobId: String, priority: Int): String {
        val job = jobs[jobId]
        if (job == null || job.state != "queued") {
            return "invalid_request"
        }
        job.priority = priority
        return "true"
    }
}
