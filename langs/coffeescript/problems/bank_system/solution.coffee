class Account
  constructor: (accountId, createdAt) ->
    @accountId = accountId
    @balance = 0
    @outgoing = 0
    @payments = {}
    @createdAt = createdAt
    @balanceHistory = [[createdAt, 0]]

  recordBalance: (timestamp) ->
    @balanceHistory.push [timestamp, @balance]

  deposit: (amount) ->
    @balance += amount
    @balance

  withdraw: (amount) ->
    return false if @balance < amount
    @balance -= amount
    @outgoing += amount
    true

  getBalanceAt: (timeAt) ->
    return null if timeAt < @createdAt
    result = null
    for [ts, balance] in @balanceHistory
      if ts <= timeAt
        result = balance
      else
        break
    result

class Simulation
  constructor: ->
    @accounts = {}
    @paymentCounter = 0
    @pendingCashbacks = []
    @CASHBACK_DELAY = 24 * 60 * 60 * 1000

  _process: (timestamp) ->
    while @pendingCashbacks.length and @pendingCashbacks[0][0] <= timestamp
      [cbTs, accountId, amount, paymentId] = @pendingCashbacks.shift()
      if @accounts[accountId]
        account = @accounts[accountId]
        account.deposit amount
        account.payments[paymentId] = "CASHBACK_RECEIVED"
        account.recordBalance cbTs

  createAccount: (timestamp, accountId) ->
    @_process timestamp
    return false if @accounts[accountId]
    @accounts[accountId] = new Account accountId, timestamp
    true

  deposit: (timestamp, accountId, amount) ->
    @_process timestamp
    return null unless @accounts[accountId]
    account = @accounts[accountId]
    result = account.deposit amount
    account.recordBalance timestamp
    result

  transfer: (timestamp, sourceId, targetId, amount) ->
    @_process timestamp
    return null unless @accounts[sourceId] and @accounts[targetId]
    return null if sourceId is targetId
    source = @accounts[sourceId]
    target = @accounts[targetId]
    return null unless source.withdraw amount
    target.deposit amount
    source.recordBalance timestamp
    target.recordBalance timestamp
    source.balance

  topSpenders: (timestamp, n) ->
    @_process timestamp
    ids = Object.keys(@accounts).sort (a, b) =>
      d = @accounts[b].outgoing - @accounts[a].outgoing
      if d isnt 0 then d else if a < b then -1 else if a > b then 1 else 0
    ids.slice(0, n).map (id) => "#{id}(#{@accounts[id].outgoing})"

  pay: (timestamp, accountId, amount) ->
    @_process timestamp
    return null unless @accounts[accountId]
    account = @accounts[accountId]
    return null unless account.withdraw amount
    @paymentCounter += 1
    paymentId = "payment#{@paymentCounter}"
    account.payments[paymentId] = "IN_PROGRESS"
    account.recordBalance timestamp
    @pendingCashbacks.push [
      timestamp + @CASHBACK_DELAY
      accountId
      Math.floor((amount * 2) / 100)
      paymentId
    ]
    paymentId

  getPaymentStatus: (timestamp, accountId, payment) ->
    @_process timestamp
    return null unless @accounts[accountId]
    return null unless payment of @accounts[accountId].payments
    @accounts[accountId].payments[payment]

  mergeAccounts: (timestamp, keepId, dropId) ->
    @_process timestamp
    return false if keepId is dropId
    return false unless @accounts[keepId] and @accounts[dropId]
    keep = @accounts[keepId]
    drop = @accounts[dropId]
    keep.balance += drop.balance
    keep.outgoing += drop.outgoing
    Object.assign keep.payments, drop.payments
    keep.balanceHistory = keep.balanceHistory.concat drop.balanceHistory
    keep.balanceHistory.sort (a, b) -> a[0] - b[0]
    keep.createdAt = Math.min keep.createdAt, drop.createdAt
    keep.recordBalance timestamp
    @pendingCashbacks = @pendingCashbacks.map (row) ->
      if row[1] is dropId then [row[0], keepId, row[2], row[3]] else row
    delete @accounts[dropId]
    true

  getBalance: (timestamp, accountId, timeAt) ->
    @_process timestamp
    return null unless @accounts[accountId]
    @accounts[accountId].getBalanceAt timeAt

module.exports = { Simulation }
