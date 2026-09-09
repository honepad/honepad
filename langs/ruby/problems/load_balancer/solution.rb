# frozen_string_literal: true

class Backend
  attr_accessor :backend_id, :health, :weight, :inflight

  def initialize(backend_id)
    @backend_id = backend_id
    @health = true
    @weight = 1
    @inflight = 0
  end
end

class Simulation
  def initialize
    @backends = []
    @by_id = {}
    @cursor = 0
    @sticky_map = {}
    @use_least = false
  end

  def add_backend(backend_id)
    return 'false' if @by_id.key?(backend_id)

    item = Backend.new(backend_id)
    @backends << item
    @by_id[backend_id] = item
    'true'
  end

  def set_health(backend_id, flag)
    item = @by_id[backend_id]
    return 'invalid_request' if item.nil? || ![0, 1].include?(flag)

    item.health = flag == 1
    reset_cycle
    'true'
  end

  def set_weight(backend_id, weight)
    item = @by_id[backend_id]
    return 'invalid_request' if item.nil? || weight <= 0

    item.weight = weight
    reset_cycle
    'true'
  end

  def route
    take
  end

  def sticky(client_id)
    bound = @sticky_map[client_id]
    item = bound ? @by_id[bound] : nil
    if item && item.health
      item.inflight += 1
      return item.backend_id
    end
    chosen = take
    @sticky_map[client_id] = chosen unless chosen.empty?
    chosen
  end

  def done(backend_id)
    item = @by_id[backend_id]
    return 'invalid_request' if item.nil? || item.inflight <= 0

    item.inflight -= 1
    @use_least = true
    'true'
  end

  private

  def reset_cycle
    @cursor = 0
    @use_least = false
    @backends.each { |item| item.inflight = 0 }
  end

  def tickets(items)
    items.flat_map { |item| [item] * item.weight }
  end

  def pick
    healthy = @backends.select(&:health)
    return nil if healthy.empty?

    pool = healthy
    if @use_least
      least = healthy.map(&:inflight).min
      pool = healthy.select { |item| item.inflight == least }
    end
    tix = tickets(pool)
    return nil if tix.empty?

    chosen = tix[@cursor % tix.length]
    @cursor += 1
    chosen
  end

  def take
    item = pick
    return '' if item.nil?

    item.inflight += 1
    item.backend_id
  end
end
