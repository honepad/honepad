import java.util.{ArrayList, HashMap, Map => JMap}

class Gpu(val gpuId: String, val mem: Int, var jobId: String = null)

class Job(
    val jobId: String,
    val mem: Int,
    val seq: Int,
    var priority: Int = 0,
    var state: String = "queued",
    var gpuId: String = null
)

class Simulation {
  private val gpus: JMap[String, Gpu] = new HashMap[String, Gpu]()
  private val gpuOrder = new ArrayList[String]()
  private val jobs: JMap[String, Job] = new HashMap[String, Job]()
  private var nextSeq = 0

  def addGpu(gpuId: String, mem: Int): String = {
    if (mem <= 0) {
      return "invalid_request"
    }
    if (gpus.containsKey(gpuId)) {
      return "false"
    }
    gpus.put(gpuId, new Gpu(gpuId, mem))
    gpuOrder.add(gpuId)
    "true"
  }

  def submitJob(jobId: String, mem: Int): String = {
    if (mem <= 0) {
      return "invalid_request"
    }
    if (jobs.containsKey(jobId)) {
      return "false"
    }
    jobs.put(jobId, new Job(jobId, mem, nextSeq))
    nextSeq += 1
    "true"
  }

  def status(jobId: String): String = {
    val job = jobs.get(jobId)
    if (job == null) "" else job.state
  }

  private def place(job: Job, gpu: Gpu): Unit = {
    job.state = "running"
    job.gpuId = gpu.gpuId
    gpu.jobId = job.jobId
  }

  def assign(): String = {
    val queued = new ArrayList[Job]()
    val it = jobs.values().iterator()
    while (it.hasNext) {
      val job = it.next()
      if (job.state == "queued") {
        queued.add(job)
      }
    }
    queued.sort((a: Job, b: Job) => {
      val byPriority = Integer.compare(b.priority, a.priority)
      if (byPriority != 0) byPriority else Integer.compare(a.seq, b.seq)
    })
    var i = 0
    while (i < queued.size()) {
      val job = queued.get(i)
      var g = 0
      while (g < gpuOrder.size()) {
        val gpu = gpus.get(gpuOrder.get(g))
        if (gpu.jobId == null && gpu.mem >= job.mem) {
          place(job, gpu)
          return job.jobId
        }
        g += 1
      }
      i += 1
    }
    ""
  }

  def complete(jobId: String): String = {
    val job = jobs.get(jobId)
    if (job == null || job.state != "running" || job.gpuId == null) {
      return "invalid_request"
    }
    gpus.get(job.gpuId).jobId = null
    job.gpuId = null
    job.state = "done"
    "true"
  }

  def cancel(jobId: String): String = {
    val job = jobs.get(jobId)
    if (job == null || job.state == "done") {
      return "invalid_request"
    }
    val running = job.state == "running"
    if (running && job.gpuId != null) {
      gpus.get(job.gpuId).jobId = null
    }
    jobs.remove(jobId)
    if (running) {
      assign()
    }
    "true"
  }

  def setPriority(jobId: String, priority: Int): String = {
    val job = jobs.get(jobId)
    if (job == null || job.state != "queued") {
      return "invalid_request"
    }
    job.priority = priority
    "true"
  }
}
