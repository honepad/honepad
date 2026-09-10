# frozen_string_literal: true

class Simulation
  def initialize
    @subs = {}
    @inbox_map = {}
    @retained = {}
  end

  def subscribe(topic, client)
    clients = @subs[topic] ||= []
    return 'false' if clients.include?(client)

    clients << client
    if @retained.key?(topic)
      (@inbox_map[client] ||= []) << "#{topic}:#{@retained[topic]}"
    end
    'true'
  end

  def unsubscribe(topic, client)
    clients = @subs[topic]
    return 'false' if clients.nil? || !clients.include?(client)

    clients.delete(client)
    @subs.delete(topic) if clients.empty?
    'true'
  end

  def publish(topic, message)
    clients = @subs[topic] || []
    payload = "#{topic}:#{message}"
    clients.each do |client|
      (@inbox_map[client] ||= []) << payload
    end
    clients.length.to_s
  end

  def inbox(client)
    (@inbox_map[client] || []).join(', ')
  end

  def list_topics
    @subs.keys.sort.join(', ')
  end

  def subscribers(topic)
    (@subs[topic] || []).sort.join(', ')
  end

  def peek(client)
    items = @inbox_map[client] || []
    items.empty? ? '' : items[0]
  end

  def ack(client, n)
    return 'invalid_request' if n <= 0 || !@inbox_map.key?(client)

    items = @inbox_map[client]
    return 'invalid_request' if n > items.length

    items.shift(n)
    items.length.to_s
  end

  def retain(topic, message)
    @retained[topic] = message
    ''
  end
end
