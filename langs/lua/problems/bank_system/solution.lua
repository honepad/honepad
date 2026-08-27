Account = {}
Account.__index = Account

function Account.new(account_id, created_at)
  local self = setmetatable({}, Account)
  self.account_id = account_id
  self.balance = 0
  self.outgoing = 0
  self.payments = {}
  self.created_at = created_at
  self.balance_history = { { created_at, 0 } }
  return self
end

function Account:record_balance(timestamp)
  self.balance_history[#self.balance_history + 1] = { timestamp, self.balance }
end

function Account:deposit(amount)
  self.balance = self.balance + amount
  return self.balance
end

function Account:withdraw(amount)
  if self.balance < amount then
    return false
  end
  self.balance = self.balance - amount
  self.outgoing = self.outgoing + amount
  return true
end

function Account:get_balance_at(time_at)
  if time_at < self.created_at then
    return nil
  end
  local result = nil
  for _, row in ipairs(self.balance_history) do
    if row[1] > time_at then
      break
    end
    result = row[2]
  end
  return result
end

Simulation = {}
Simulation.__index = Simulation

local CASHBACK_DELAY = 24 * 60 * 60 * 1000

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.accounts = {}
  self.payment_counter = 0
  self.pending_cashbacks = {}
  return self
end

function Simulation:process_cashbacks(timestamp)
  while #self.pending_cashbacks > 0 and self.pending_cashbacks[1][1] <= timestamp do
    local row = table.remove(self.pending_cashbacks, 1)
    local cb_timestamp, account_id, amount, payment_id = row[1], row[2], row[3], row[4]
    local account = self.accounts[account_id]
    if account then
      account:deposit(amount)
      account.payments[payment_id] = "CASHBACK_RECEIVED"
      account:record_balance(cb_timestamp)
    end
  end
end

function Simulation:create_account(timestamp, account_id)
  self:process_cashbacks(timestamp)
  if self.accounts[account_id] then
    return false
  end
  self.accounts[account_id] = Account.new(account_id, timestamp)
  return true
end

function Simulation:deposit(timestamp, account_id, amount)
  self:process_cashbacks(timestamp)
  local account = self.accounts[account_id]
  if not account then
    return nil
  end
  local result = account:deposit(amount)
  account:record_balance(timestamp)
  return result
end

function Simulation:transfer(timestamp, source_account_id, target_account_id, amount)
  self:process_cashbacks(timestamp)
  if not self.accounts[source_account_id] or not self.accounts[target_account_id] then
    return nil
  end
  if source_account_id == target_account_id then
    return nil
  end
  local source = self.accounts[source_account_id]
  local target = self.accounts[target_account_id]
  if not source:withdraw(amount) then
    return nil
  end
  target:deposit(amount)
  source:record_balance(timestamp)
  target:record_balance(timestamp)
  return source.balance
end

function Simulation:top_spenders(timestamp, n)
  self:process_cashbacks(timestamp)
  local ordered = {}
  for account_id in pairs(self.accounts) do
    ordered[#ordered + 1] = account_id
  end
  table.sort(ordered, function(a, b)
    local oa = self.accounts[a].outgoing
    local ob = self.accounts[b].outgoing
    if oa ~= ob then
      return oa > ob
    end
    return a < b
  end)
  if #ordered > n then
    for i = n + 1, #ordered do
      ordered[i] = nil
    end
  end
  local result = {}
  for i, account_id in ipairs(ordered) do
    result[i] = string.format("%s(%d)", account_id, self.accounts[account_id].outgoing)
  end
  return result
end

function Simulation:pay(timestamp, account_id, amount)
  self:process_cashbacks(timestamp)
  local account = self.accounts[account_id]
  if not account then
    return nil
  end
  if not account:withdraw(amount) then
    return nil
  end
  self.payment_counter = self.payment_counter + 1
  local payment_id = "payment" .. self.payment_counter
  account.payments[payment_id] = "IN_PROGRESS"
  account:record_balance(timestamp)
  local cashback_amount = amount * 2 // 100
  self.pending_cashbacks[#self.pending_cashbacks + 1] = {
    timestamp + CASHBACK_DELAY,
    account_id,
    cashback_amount,
    payment_id,
  }
  return payment_id
end

function Simulation:get_payment_status(timestamp, account_id, payment)
  self:process_cashbacks(timestamp)
  local account = self.accounts[account_id]
  if not account then
    return nil
  end
  return account.payments[payment]
end

function Simulation:merge_accounts(timestamp, account_id_1, account_id_2)
  self:process_cashbacks(timestamp)
  if account_id_1 == account_id_2 then
    return false
  end
  if not self.accounts[account_id_1] or not self.accounts[account_id_2] then
    return false
  end
  local account1 = self.accounts[account_id_1]
  local account2 = self.accounts[account_id_2]
  account1.balance = account1.balance + account2.balance
  account1.outgoing = account1.outgoing + account2.outgoing
  for payment_id, status in pairs(account2.payments) do
    account1.payments[payment_id] = status
  end
  for _, row in ipairs(account2.balance_history) do
    account1.balance_history[#account1.balance_history + 1] = row
  end
  table.sort(account1.balance_history, function(a, b)
    return a[1] < b[1]
  end)
  if account2.created_at < account1.created_at then
    account1.created_at = account2.created_at
  end
  account1:record_balance(timestamp)
  for _, cb in ipairs(self.pending_cashbacks) do
    if cb[2] == account_id_2 then
      cb[2] = account_id_1
    end
  end
  self.accounts[account_id_2] = nil
  return true
end

function Simulation:get_balance(timestamp, account_id, time_at)
  self:process_cashbacks(timestamp)
  local account = self.accounts[account_id]
  if not account then
    return nil
  end
  return account:get_balance_at(time_at)
end
