# frozen_string_literal: true

class StoredFile
  attr_accessor :name, :size, :owner

  def initialize(name, size, owner)
    @name = name
    @size = size
    @owner = owner
  end
end

class Simulation
  def initialize
    @files = {}
    @capacity = { 'admin' => nil }
    @backups = {}
  end

  def used(user_id)
    @files.values.select { |item| item.owner == user_id }.sum(&:size)
  end

  def remaining(user_id)
    cap = @capacity[user_id]
    return nil if cap.nil?

    cap - used(user_id)
  end

  def add_file(name, size)
    return 'false' if @files.key?(name)

    @files[name] = StoredFile.new(name, size, 'admin')
    'true'
  end

  def get_file_size(name)
    item = @files[name]
    item.nil? ? '' : item.size.to_s
  end

  def delete_file(name)
    item = @files.delete(name)
    item.nil? ? '' : item.size.to_s
  end

  def get_n_largest(prefix, n)
    matched = @files.values.select { |item| item.name.start_with?(prefix) }
    matched.sort_by! { |item| [-item.size, item.name] }
    matched.first(n).map { |item| "#{item.name}(#{item.size})" }.join(', ')
  end

  def add_user(user_id, capacity)
    return 'false' if @capacity.key?(user_id)

    @capacity[user_id] = capacity
    'true'
  end

  def add_file_by(user_id, name, size)
    return '' unless @capacity.key?(user_id) && !@files.key?(name)

    left = remaining(user_id)
    return '' if !left.nil? && size > left

    @files[name] = StoredFile.new(name, size, user_id)
    left = remaining(user_id)
    left.nil? ? '' : left.to_s
  end

  def merge_user(user_id1, user_id2)
    return '' if user_id1 == user_id2
    return '' unless @capacity.key?(user_id1) && @capacity.key?(user_id2)

    cap1 = @capacity[user_id1]
    cap2 = @capacity[user_id2]
    return '' if cap1.nil? || cap2.nil?

    @capacity[user_id1] = cap1 + cap2
    @files.each_value { |item| item.owner = user_id1 if item.owner == user_id2 }
    @capacity.delete(user_id2)
    @backups.delete(user_id2)
    left = remaining(user_id1)
    left.nil? ? '' : left.to_s
  end

  def backup_user(user_id)
    return '' unless @capacity.key?(user_id)

    @backups[user_id] = @files.values.select { |item| item.owner == user_id }
                              .to_h { |item| [item.name, item.size] }
    @backups[user_id].length.to_s
  end

  def restore_user(user_id)
    return '' unless @capacity.key?(user_id)

    @files.delete_if { |_name, item| item.owner == user_id }
    snapshot = @backups[user_id]
    return '0' if snapshot.nil?

    restored = 0
    snapshot.each do |name, size|
      next if @files.key?(name)

      left = remaining(user_id)
      next if !left.nil? && size > left

      @files[name] = StoredFile.new(name, size, user_id)
      restored += 1
    end
    restored.to_s
  end
end
