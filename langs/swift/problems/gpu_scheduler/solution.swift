import Foundation

final class Gpu {
  let gpuId: String
  let mem: Int64
  var jobId: String?

  init(_ gpuId: String, _ mem: Int64) {
    self.gpuId = gpuId
    self.mem = mem
  }
}

final class Job {
  let jobId: String
  let mem: Int64
  let seq: Int64
  var priority: Int64 = 0
  var state = "queued"
  var gpuId: String?

  init(_ jobId: String, _ mem: Int64, _ seq: Int64) {
    self.jobId = jobId
    self.mem = mem
    self.seq = seq
  }
}

final class Simulation: Harness {
  private var gpus: [String: Gpu] = [:]
  private var gpuOrder: [String] = []
  private var jobs: [String: Job] = [:]
  private var nextSeq: Int64 = 0

  private func place(_ job: Job, _ gpu: Gpu) {
    job.state = "running"
    job.gpuId = gpu.gpuId
    gpu.jobId = job.jobId
  }

  private func addGpu(_ gpuId: String, _ mem: Int64) -> String {
    if mem <= 0 {
      return "invalid_request"
    }
    if gpus[gpuId] != nil {
      return "false"
    }
    gpus[gpuId] = Gpu(gpuId, mem)
    gpuOrder.append(gpuId)
    return "true"
  }

  private func submitJob(_ jobId: String, _ mem: Int64) -> String {
    if mem <= 0 {
      return "invalid_request"
    }
    if jobs[jobId] != nil {
      return "false"
    }
    jobs[jobId] = Job(jobId, mem, nextSeq)
    nextSeq += 1
    return "true"
  }

  private func status(_ jobId: String) -> String {
    guard let job = jobs[jobId] else {
      return ""
    }
    return job.state
  }

  private func assign() -> String {
    var queued = jobs.values.filter { $0.state == "queued" }
    queued.sort { left, right in
      if left.priority != right.priority {
        return left.priority > right.priority
      }
      return left.seq < right.seq
    }
    for job in queued {
      for gpuId in gpuOrder {
        let gpu = gpus[gpuId]!
        if gpu.jobId == nil && gpu.mem >= job.mem {
          place(job, gpu)
          return job.jobId
        }
      }
    }
    return ""
  }

  private func complete(_ jobId: String) -> String {
    guard let job = jobs[jobId], job.state == "running", let gpuId = job.gpuId else {
      return "invalid_request"
    }
    gpus[gpuId]?.jobId = nil
    job.gpuId = nil
    job.state = "done"
    return "true"
  }

  private func cancel(_ jobId: String) -> String {
    guard let job = jobs[jobId], job.state != "done" else {
      return "invalid_request"
    }
    let running = job.state == "running"
    if running, let gpuId = job.gpuId {
      gpus[gpuId]?.jobId = nil
    }
    jobs.removeValue(forKey: jobId)
    if running {
      _ = assign()
    }
    return "true"
  }

  private func setPriority(_ jobId: String, _ priority: Int64) -> String {
    guard let job = jobs[jobId], job.state == "queued" else {
      return "invalid_request"
    }
    job.priority = priority
    return "true"
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "addGpu":
      text = try addGpu(argStr(args, 0), argI64(args, 1))
    case "submitJob":
      text = try submitJob(argStr(args, 0), argI64(args, 1))
    case "status":
      text = try status(argStr(args, 0))
    case "assign":
      text = assign()
    case "complete":
      text = try complete(argStr(args, 0))
    case "cancel":
      text = try cancel(argStr(args, 0))
    case "setPriority":
      text = try setPriority(argStr(args, 0), argI64(args, 1))
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
