# frozen_string_literal: true

class Item
  attr_accessor :sku, :name, :qty, :reserved

  def initialize(sku, name)
    @sku = sku
    @name = name
    @qty = 0
    @reserved = 0
  end
end

class Simulation
  def initialize
    @items = {}
  end

  def create_item(sku, name)
    return 'false' if @items.key?(sku)

    @items[sku] = Item.new(sku, name)
    'true'
  end

  def stock(sku, delta)
    item = @items[sku]
    return '' if item.nil?

    nxt = item.qty + delta
    return 'invalid_request' if nxt < item.reserved

    item.qty = nxt
    item.qty.to_s
  end

  def get_qty(sku)
    item = @items[sku]
    return '' if item.nil?

    item.qty.to_s
  end

  def list_low(threshold)
    matched = @items.values.select { |item| item.qty <= threshold }
    matched.sort_by! { |item| [item.qty, item.sku] }
    matched.map { |item| "#{item.sku}(#{item.qty})" }.join(', ')
  end

  def reserve(sku, n)
    item = @items[sku]
    return 'invalid_request' if item.nil? || n <= 0 || item.reserved + n > item.qty

    item.reserved += n
    'true'
  end

  def release(sku, n)
    item = @items[sku]
    return 'invalid_request' if item.nil? || n <= 0 || n > item.reserved

    item.reserved -= n
    'true'
  end

  def ship(sku, n)
    item = @items[sku]
    return 'invalid_request' if item.nil? || n <= 0 || n > item.reserved

    item.reserved -= n
    item.qty -= n
    'true'
  end
end
