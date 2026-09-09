# frozen_string_literal: true

class Gpu
  attr_accessor :gpu_id, :mem, :job_id

  def initialize(gpu_id, mem)
    @gpu_id = gpu_id
    @mem = mem
    @job_id = nil
  end
end

class Job
  attr_accessor :job_id, :mem, :seq, :priority, :state, :gpu_id

  def initialize(job_id, mem, seq)
    @job_id = job_id
    @mem = mem
    @seq = seq
    @priority = 0
    @state = 'queued'
    @gpu_id = nil
  end
end

class Simulation
  def initialize
    @gpus = {}
    @gpu_order = []
    @jobs = {}
    @next_seq = 0
  end

  def add_gpu(gpu_id, mem)
    return 'invalid_request' if mem <= 0
    return 'false' if @gpus.key?(gpu_id)

    @gpus[gpu_id] = Gpu.new(gpu_id, mem)
    @gpu_order << gpu_id
    'true'
  end

  def submit_job(job_id, mem)
    return 'invalid_request' if mem <= 0
    return 'false' if @jobs.key?(job_id)

    @jobs[job_id] = Job.new(job_id, mem, @next_seq)
    @next_seq += 1
    'true'
  end

  def status(job_id)
    job = @jobs[job_id]
    return '' if job.nil?

    job.state
  end

  def assign
    queued = @jobs.values.select { |job| job.state == 'queued' }
    queued.sort_by! { |job| [-job.priority, job.seq] }
    queued.each do |job|
      @gpu_order.each do |gpu_id|
        gpu = @gpus[gpu_id]
        next unless gpu.job_id.nil? && gpu.mem >= job.mem

        place(job, gpu)
        return job.job_id
      end
    end
    ''
  end

  def complete(job_id)
    job = @jobs[job_id]
    return 'invalid_request' if job.nil? || job.state != 'running' || job.gpu_id.nil?

    @gpus[job.gpu_id].job_id = nil
    job.gpu_id = nil
    job.state = 'done'
    'true'
  end

  def cancel(job_id)
    job = @jobs[job_id]
    return 'invalid_request' if job.nil? || job.state == 'done'

    @gpus[job.gpu_id].job_id = nil if job.state == 'running' && !job.gpu_id.nil?
    @jobs.delete(job_id)
    assign if job.state == 'running'
    'true'
  end

  def set_priority(job_id, priority)
    job = @jobs[job_id]
    return 'invalid_request' if job.nil? || job.state != 'queued'

    job.priority = priority
    'true'
  end

  private

  def place(job, gpu)
    job.state = 'running'
    job.gpu_id = gpu.gpu_id
    gpu.job_id = job.job_id
  end
end
