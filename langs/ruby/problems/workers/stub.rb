class Simulation
  def initialize
  end
  def add_worker(worker_id, position, compensation)
    raise 'not implemented'
  end
  def register(worker_id, timestamp)
    raise 'not implemented'
  end
  def get(worker_id)
    raise 'not implemented'
  end
  def top_n_workers(n, position)
    raise 'not implemented'
  end
  def promote(worker_id, new_position, new_compensation, start_timestamp)
    raise 'not implemented'
  end
  def calc_salary(worker_id, start_timestamp, end_timestamp)
    raise 'not implemented'
  end
end
