class Simulation
  def initialize
  end
  def create_account(timestamp, account_id)
    raise 'not implemented'
  end
  def deposit(timestamp, account_id, amount)
    raise 'not implemented'
  end
  def transfer(timestamp, source_account_id, target_account_id, amount)
    raise 'not implemented'
  end
  def top_spenders(timestamp, n)
    raise 'not implemented'
  end
  def pay(timestamp, account_id, amount)
    raise 'not implemented'
  end
  def get_payment_status(timestamp, account_id, payment)
    raise 'not implemented'
  end
  def merge_accounts(timestamp, account_id_1, account_id_2)
    raise 'not implemented'
  end
  def get_balance(timestamp, account_id, time_at)
    raise 'not implemented'
  end
end
