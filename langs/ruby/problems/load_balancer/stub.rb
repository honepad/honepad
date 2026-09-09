class Simulation
  def initialize
  end
  def add_backend(backend_id)
    raise 'not implemented'
  end
  def route()
    raise 'not implemented'
  end
  def set_health(backend_id, flag)
    raise 'not implemented'
  end
  def set_weight(backend_id, weight)
    raise 'not implemented'
  end
  def sticky(client_id)
    raise 'not implemented'
  end
  def done(backend_id)
    raise 'not implemented'
  end
end
