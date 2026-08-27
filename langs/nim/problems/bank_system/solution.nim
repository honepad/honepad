import std/[tables, deques, options, algorithm]

const cashbackDelay = 24'i64 * 60 * 60 * 1000

type
  Account = ref object
    accountId: string
    balance: int64
    outgoing: int64
    payments: Table[string, string]
    createdAt: int64
    balanceHistory: seq[(int64, int64)]

  Simulation = ref object
    accounts: Table[string, Account]
    paymentCounter: int
    pendingCashbacks: Deque[(int64, string, int64, string)]

proc newAccount(accountId: string; createdAt: int64): Account =
  Account(
    accountId: accountId,
    balance: 0,
    outgoing: 0,
    payments: initTable[string, string](),
    createdAt: createdAt,
    balanceHistory: @[(createdAt, 0'i64)],
  )

proc recordBalance(account: Account; timestamp: int64) =
  account.balanceHistory.add((timestamp, account.balance))

proc depositAmount(account: Account; amount: int64): int64 =
  account.balance += amount
  result = account.balance

proc withdraw(account: Account; amount: int64): bool =
  if account.balance < amount:
    return false
  account.balance -= amount
  account.outgoing += amount
  result = true

proc getBalanceAt(account: Account; timeAt: int64): Option[int64] =
  if timeAt < account.createdAt:
    return none(int64)
  var found = none(int64)
  for (ts, balance) in account.balanceHistory:
    if ts <= timeAt:
      found = some(balance)
    else:
      break
  result = found

proc processCashbacks(self: Simulation; timestamp: int64) =
  while self.pendingCashbacks.len > 0 and self.pendingCashbacks.peekFirst[0] <= timestamp:
    let (cbTimestamp, accountId, amount, paymentId) = self.pendingCashbacks.popFirst()
    if accountId in self.accounts:
      let account = self.accounts[accountId]
      discard depositAmount(account, amount)
      account.payments[paymentId] = "CASHBACK_RECEIVED"
      recordBalance(account, cbTimestamp)

proc createAccount(self: Simulation; timestamp: int64; accountId: string): bool =
  self.processCashbacks(timestamp)
  if accountId in self.accounts:
    return false
  self.accounts[accountId] = newAccount(accountId, timestamp)
  result = true

proc deposit(
    self: Simulation; timestamp: int64; accountId: string; amount: int64
): Option[int64] =
  self.processCashbacks(timestamp)
  if accountId notin self.accounts:
    return none(int64)
  let account = self.accounts[accountId]
  let value = depositAmount(account, amount)
  recordBalance(account, timestamp)
  result = some(value)

proc transfer(
    self: Simulation;
    timestamp: int64;
    sourceAccountId: string;
    targetAccountId: string;
    amount: int64;
): Option[int64] =
  self.processCashbacks(timestamp)
  if sourceAccountId notin self.accounts or targetAccountId notin self.accounts:
    return none(int64)
  if sourceAccountId == targetAccountId:
    return none(int64)
  let source = self.accounts[sourceAccountId]
  let target = self.accounts[targetAccountId]
  if not withdraw(source, amount):
    return none(int64)
  discard depositAmount(target, amount)
  recordBalance(source, timestamp)
  recordBalance(target, timestamp)
  result = some(source.balance)

proc topSpenders(self: Simulation; timestamp: int64; n: int64): seq[string] =
  self.processCashbacks(timestamp)
  var ids: seq[string] = @[]
  for accountId in self.accounts.keys:
    ids.add(accountId)
  ids.sort(
    proc (a, b: string): int =
      let outgoingCmp = cmp(self.accounts[b].outgoing, self.accounts[a].outgoing)
      if outgoingCmp != 0:
        return outgoingCmp
      result = cmp(a, b)
  )
  let take = min(int(n), ids.len)
  result = newSeq[string](take)
  for i in 0 ..< take:
    let accountId = ids[i]
    result[i] = accountId & "(" & $self.accounts[accountId].outgoing & ")"

proc pay(
    self: Simulation; timestamp: int64; accountId: string; amount: int64
): Option[string] =
  self.processCashbacks(timestamp)
  if accountId notin self.accounts:
    return none(string)
  let account = self.accounts[accountId]
  if not withdraw(account, amount):
    return none(string)
  inc self.paymentCounter
  let paymentId = "payment" & $self.paymentCounter
  account.payments[paymentId] = "IN_PROGRESS"
  recordBalance(account, timestamp)
  let cashbackAmount = (amount * 2) div 100
  self.pendingCashbacks.addLast(
    (timestamp + cashbackDelay, accountId, cashbackAmount, paymentId)
  )
  result = some(paymentId)

proc getPaymentStatus(
    self: Simulation; timestamp: int64; accountId: string; payment: string
): Option[string] =
  self.processCashbacks(timestamp)
  if accountId notin self.accounts:
    return none(string)
  let account = self.accounts[accountId]
  if payment notin account.payments:
    return none(string)
  result = some(account.payments[payment])

proc mergeAccounts(
    self: Simulation; timestamp: int64; accountId1: string; accountId2: string
): bool =
  self.processCashbacks(timestamp)
  if accountId1 == accountId2:
    return false
  if accountId1 notin self.accounts or accountId2 notin self.accounts:
    return false
  let account1 = self.accounts[accountId1]
  let account2 = self.accounts[accountId2]
  account1.balance += account2.balance
  account1.outgoing += account2.outgoing
  for paymentId, status in account2.payments:
    account1.payments[paymentId] = status
  account1.balanceHistory.add(account2.balanceHistory)
  account1.balanceHistory.sort(
    proc (a, b: (int64, int64)): int =
      cmp(a[0], b[0])
  )
  account1.createdAt = min(account1.createdAt, account2.createdAt)
  recordBalance(account1, timestamp)
  var pending: seq[(int64, string, int64, string)] = @[]
  while self.pendingCashbacks.len > 0:
    pending.add(self.pendingCashbacks.popFirst())
  for (cbTs, accId, amount, paymentId) in pending:
    var mapped = accId
    if accId == accountId2:
      mapped = accountId1
    self.pendingCashbacks.addLast((cbTs, mapped, amount, paymentId))
  self.accounts.del(accountId2)
  result = true

proc getBalance(
    self: Simulation; timestamp: int64; accountId: string; timeAt: int64
): Option[int64] =
  self.processCashbacks(timestamp)
  if accountId notin self.accounts:
    return none(int64)
  result = getBalanceAt(self.accounts[accountId], timeAt)
