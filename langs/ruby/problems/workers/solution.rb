# frozen_string_literal: true

class Worker
  attr_accessor :worker_id, :position, :compensation, :in_office, :entered_at, :finished, :pending_promo

  def initialize(worker_id, position, compensation)
    @worker_id = worker_id
    @position = position
    @compensation = compensation
    @in_office = false
    @entered_at = nil
    @finished = []
    @pending_promo = nil
  end

  def total_time
    @finished.sum { |start_ts, end_ts, _rate, _pos| end_ts - start_ts }
  end

  def position_time(position)
    @finished.sum do |start_ts, end_ts, _rate, pos|
      pos == position ? end_ts - start_ts : 0
    end
  end

  def apply_promo_on_enter(timestamp)
    return if @pending_promo.nil?

    new_pos, new_comp, start_ts = @pending_promo
    return if timestamp < start_ts

    @position = new_pos
    @compensation = new_comp
    @pending_promo = nil
  end
end

class Simulation
  def initialize
    @workers = {}
  end

  def add_worker(worker_id, position, compensation)
    return 'false' if @workers.key?(worker_id)

    @workers[worker_id] = Worker.new(worker_id, position, compensation)
    'true'
  end

  def register(worker_id, timestamp)
    worker = @workers[worker_id]
    return 'invalid_request' if worker.nil?

    if worker.in_office
      worker.finished << [worker.entered_at, timestamp, worker.compensation, worker.position]
      worker.in_office = false
      worker.entered_at = nil
      return 'registered'
    end
    worker.apply_promo_on_enter(timestamp)
    worker.in_office = true
    worker.entered_at = timestamp
    'registered'
  end

  def get(worker_id)
    worker = @workers[worker_id]
    return '' if worker.nil?

    worker.total_time.to_s
  end

  def top_n_workers(n, position)
    matched = @workers.values.select { |w| w.position == position }
    matched.sort_by! { |w| [-w.position_time(position), w.worker_id] }
    matched.first(n).map { |w| "#{w.worker_id}(#{w.position_time(position)})" }.join(', ')
  end

  def promote(worker_id, new_position, new_compensation, start_timestamp)
    worker = @workers[worker_id]
    return 'invalid_request' if worker.nil? || !worker.pending_promo.nil?

    worker.pending_promo = [new_position, new_compensation, start_timestamp]
    'success'
  end

  def calc_salary(worker_id, start_timestamp, end_timestamp)
    worker = @workers[worker_id]
    return '' if worker.nil?

    total = 0
    worker.finished.each do |session_start, session_end, rate, _pos|
      lo = [session_start, start_timestamp].max
      hi = [session_end, end_timestamp].min
      total += (hi - lo) * rate if hi > lo
    end
    total.to_s
  end
end
