# frozen_string_literal: true

class InMemoryDatabase
  def initialize
    @database = {}
    @backup_timestamps = []
    @backup_states = []
  end

  def set_internal(key, field, value, expiry)
    @database[key] ||= {}
    @database[key][field] = [value, expiry]
    ''
  end

  def alive?(key, field, timestamp)
    return false unless @database.key?(key) && @database[key].key?(field)

    expiry = @database[key][field][1]
    return true if expiry.nil?

    timestamp < expiry
  end

  def set(key, field, value)
    set_internal(key, field, value, nil)
  end

  def get(key, field)
    return '' unless @database.key?(key) && @database[key].key?(field)

    @database[key][field][0]
  end

  def delete(key, field)
    return 'false' unless @database.key?(key) && @database[key].key?(field)

    @database[key].delete(field)
    'true'
  end

  def scan(key)
    return '' unless @database.key?(key)

    @database[key].keys.sort.map { |field| "#{field}(#{@database[key][field][0]})" }.join(', ')
  end

  def scan_by_prefix(key, prefix)
    return '' unless @database.key?(key)

    @database[key].keys.select { |field| field.start_with?(prefix) }.sort
                  .map { |field| "#{field}(#{@database[key][field][0]})" }.join(', ')
  end

  def set_at(key, field, value, _timestamp)
    set_internal(key, field, value, nil)
  end

  def set_at_with_ttl(key, field, value, timestamp, ttl)
    set_internal(key, field, value, timestamp + ttl)
  end

  def delete_at(key, field, timestamp)
    return 'false' unless alive?(key, field, timestamp)

    @database[key].delete(field)
    'true'
  end

  def get_at(key, field, timestamp)
    return '' unless alive?(key, field, timestamp)

    @database[key][field][0]
  end

  def scan_at(key, timestamp)
    return '' unless @database.key?(key)

    @database[key].keys.select { |field| alive?(key, field, timestamp) }.sort
                  .map { |field| "#{field}(#{@database[key][field][0]})" }.join(', ')
  end

  def scan_by_prefix_at(key, prefix, timestamp)
    return '' unless @database.key?(key)

    @database[key].keys.select { |field| field.start_with?(prefix) && alive?(key, field, timestamp) }
                  .sort.map { |field| "#{field}(#{@database[key][field][0]})" }.join(', ')
  end

  def backup(timestamp)
    state = {}
    @database.each do |key, fields|
      fields.each do |field, (value, expiry)|
        next unless alive?(key, field, timestamp)

        remaining = expiry.nil? ? nil : expiry - timestamp
        state[key] ||= {}
        state[key][field] = [value, remaining]
      end
    end
    @backup_timestamps << timestamp
    @backup_states << state
    state.length.to_s
  end

  def restore(timestamp, timestamp_to_restore)
    idx = -1
    @backup_timestamps.each_with_index do |ts, i|
      idx = i if ts <= timestamp_to_restore
    end
    backup_state = @backup_states[idx]
    @database = {}
    backup_state.each do |key, fields|
      fields.each do |field, (value, remaining)|
        expiry = remaining.nil? ? nil : timestamp + remaining
        set_internal(key, field, value, expiry)
      end
    end
    ''
  end
end
