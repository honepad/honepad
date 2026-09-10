class Simulation
  def initialize
  end
  def subscribe(topic, client)
    raise 'not implemented'
  end
  def unsubscribe(topic, client)
    raise 'not implemented'
  end
  def publish(topic, message)
    raise 'not implemented'
  end
  def inbox(client)
    raise 'not implemented'
  end
  def list_topics
    raise 'not implemented'
  end
  def subscribers(topic)
    raise 'not implemented'
  end
  def peek(client)
    raise 'not implemented'
  end
  def ack(client, n)
    raise 'not implemented'
  end
  def retain(topic, message)
    raise 'not implemented'
  end
end
