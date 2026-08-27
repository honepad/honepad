# frozen_string_literal: true

class Account
  attr_accessor :account_id, :balance, :outgoing, :payments, :created_at, :balance_history

  def initialize(account_id, created_at)
    @account_id = account_id
    @balance = 0
    @outgoing = 0
    @payments = {}
    @created_at = created_at
    @balance_history = [[created_at, 0]]
  end

  def record_balance(timestamp)
    @balance_history << [timestamp, @balance]
  end

  def deposit(amount)
    @balance += amount
    @balance
  end

  def withdraw(amount)
    return false if @balance < amount

    @balance -= amount
    @outgoing += amount
    true
  end

  def get_balance_at(time_at)
    return nil if time_at < @created_at

    result = nil
    @balance_history.each do |ts, balance|
      break if ts > time_at

      result = balance
    end
    result
  end
end

class Simulation
  CASHBACK_DELAY = 24 * 60 * 60 * 1000

  def initialize
    @accounts = {}
    @payment_counter = 0
    @pending_cashbacks = []
  end

  def process_cashbacks(timestamp)
    while !@pending_cashbacks.empty? && @pending_cashbacks[0][0] <= timestamp
      cb_timestamp, account_id, amount, payment_id = @pending_cashbacks.shift
      account = @accounts[account_id]
      next unless account

      account.deposit(amount)
      account.payments[payment_id] = 'CASHBACK_RECEIVED'
      account.record_balance(cb_timestamp)
    end
  end

  def create_account(timestamp, account_id)
    process_cashbacks(timestamp)
    return false if @accounts.key?(account_id)

    @accounts[account_id] = Account.new(account_id, timestamp)
    true
  end

  def deposit(timestamp, account_id, amount)
    process_cashbacks(timestamp)
    account = @accounts[account_id]
    return nil unless account

    result = account.deposit(amount)
    account.record_balance(timestamp)
    result
  end

  def transfer(timestamp, source_account_id, target_account_id, amount)
    process_cashbacks(timestamp)
    return nil unless @accounts.key?(source_account_id) && @accounts.key?(target_account_id)
    return nil if source_account_id == target_account_id

    source = @accounts[source_account_id]
    target = @accounts[target_account_id]
    return nil unless source.withdraw(amount)

    target.deposit(amount)
    source.record_balance(timestamp)
    target.record_balance(timestamp)
    source.balance
  end

  def top_spenders(timestamp, n)
    process_cashbacks(timestamp)
    ordered = @accounts.keys.sort_by { |acc| [-@accounts[acc].outgoing, acc] }
    ordered.first(n).map { |acc| "#{acc}(#{@accounts[acc].outgoing})" }
  end

  def pay(timestamp, account_id, amount)
    process_cashbacks(timestamp)
    account = @accounts[account_id]
    return nil unless account
    return nil unless account.withdraw(amount)

    @payment_counter += 1
    payment_id = "payment#{@payment_counter}"
    account.payments[payment_id] = 'IN_PROGRESS'
    account.record_balance(timestamp)
    cashback_amount = amount * 2 / 100
    @pending_cashbacks << [timestamp + CASHBACK_DELAY, account_id, cashback_amount, payment_id]
    payment_id
  end

  def get_payment_status(timestamp, account_id, payment)
    process_cashbacks(timestamp)
    account = @accounts[account_id]
    return nil unless account

    account.payments[payment]
  end

  def merge_accounts(timestamp, account_id_1, account_id_2)
    process_cashbacks(timestamp)
    return false if account_id_1 == account_id_2
    return false unless @accounts.key?(account_id_1) && @accounts.key?(account_id_2)

    account1 = @accounts[account_id_1]
    account2 = @accounts[account_id_2]
    account1.balance += account2.balance
    account1.outgoing += account2.outgoing
    account1.payments.merge!(account2.payments)
    account1.balance_history.concat(account2.balance_history)
    account1.balance_history.sort_by! { |row| row[0] }
    account1.created_at = [account1.created_at, account2.created_at].min
    account1.record_balance(timestamp)
    @pending_cashbacks.map! do |cb_ts, acc_id, amount, payment_id|
      acc_id = account_id_1 if acc_id == account_id_2
      [cb_ts, acc_id, amount, payment_id]
    end
    @accounts.delete(account_id_2)
    true
  end

  def get_balance(timestamp, account_id, time_at)
    process_cashbacks(timestamp)
    account = @accounts[account_id]
    return nil unless account

    account.get_balance_at(time_at)
  end
end
