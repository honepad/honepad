class InMemoryDatabase
  def initialize
  end
  def set(key, field, value)
    raise 'not implemented'
  end
  def get(key, field)
    raise 'not implemented'
  end
  def delete(key, field)
    raise 'not implemented'
  end
  def scan(key)
    raise 'not implemented'
  end
  def scan_by_prefix(key, prefix)
    raise 'not implemented'
  end
  def set_at(key, field, value, timestamp)
    raise 'not implemented'
  end
  def set_at_with_ttl(key, field, value, timestamp, ttl)
    raise 'not implemented'
  end
  def delete_at(key, field, timestamp)
    raise 'not implemented'
  end
  def get_at(key, field, timestamp)
    raise 'not implemented'
  end
  def scan_at(key, timestamp)
    raise 'not implemented'
  end
  def scan_by_prefix_at(key, prefix, timestamp)
    raise 'not implemented'
  end
  def backup(timestamp)
    raise 'not implemented'
  end
  def restore(timestamp, timestamp_to_restore)
    raise 'not implemented'
  end
end
