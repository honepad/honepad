class Simulation
  def initialize
  end
  def allow(key, timestamp)
    raise 'not implemented'
  end
  def configure(key, limit, window)
    raise 'not implemented'
  end
  def remaining(key, timestamp)
    raise 'not implemented'
  end
  def allow_weighted(key, cost, timestamp)
    raise 'not implemented'
  end
end
