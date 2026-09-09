class Simulation
  def initialize
  end
  def create_item(sku, name)
    raise 'not implemented'
  end
  def stock(sku, delta)
    raise 'not implemented'
  end
  def get_qty(sku)
    raise 'not implemented'
  end
  def list_low(threshold)
    raise 'not implemented'
  end
  def reserve(sku, n)
    raise 'not implemented'
  end
  def release(sku, n)
    raise 'not implemented'
  end
  def ship(sku, n)
    raise 'not implemented'
  end
end
