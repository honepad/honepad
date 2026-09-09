# frozen_string_literal: true

class KeyState
  attr_accessor :limit, :window, :window_id, :used

  def initialize
    @limit = 3
    @window = 10
    @window_id = nil
    @used = 0
  end
end

class Simulation
  def initialize
    @keys = {}
  end

  def allow(key, timestamp)
    allow_weighted(key, 1, timestamp)
  end

  def configure(key, limit, window)
    return 'invalid_request' if limit <= 0 || window <= 0

    item = state(key)
    item.limit = limit
    item.window = window
    item.window_id = nil
    item.used = 0
    'true'
  end

  def remaining(key, timestamp)
    item = state(key)
    used = used_at(item, timestamp, false)
    (item.limit - used).to_s
  end

  def allow_weighted(key, cost, timestamp)
    return 'invalid_request' if cost <= 0

    item = state(key)
    used_at(item, timestamp, true)
    return 'false' if item.used + cost > item.limit

    item.used += cost
    'true'
  end

  private

  def state(key)
    @keys[key] ||= KeyState.new
  end

  def used_at(item, timestamp, persist)
    window_id = timestamp / item.window
    if item.window_id.nil? || window_id != item.window_id
      if persist
        item.window_id = window_id
        item.used = 0
      end
      return 0
    end
    item.used
  end
end
