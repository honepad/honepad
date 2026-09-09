class Simulation
  def initialize
  end
  def add_gpu(gpu_id, mem)
    raise 'not implemented'
  end
  def submit_job(job_id, mem)
    raise 'not implemented'
  end
  def status(job_id)
    raise 'not implemented'
  end
  def assign()
    raise 'not implemented'
  end
  def complete(job_id)
    raise 'not implemented'
  end
  def cancel(job_id)
    raise 'not implemented'
  end
  def set_priority(job_id, priority)
    raise 'not implemented'
  end
end
