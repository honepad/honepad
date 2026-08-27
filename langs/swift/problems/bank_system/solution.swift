import Foundation

final class Account {
  var accountId: String
  var balance: Int64 = 0
  var outgoing: Int64 = 0
  var payments: [String: String] = [:]
  var createdAt: Int64
  var balanceHistory: [(Int64, Int64)]

  init(accountId: String, createdAt: Int64) {
    self.accountId = accountId
    self.createdAt = createdAt
    self.balanceHistory = [(createdAt, 0)]
  }

  func recordBalance(_ timestamp: Int64) {
    balanceHistory.append((timestamp, balance))
  }

  func deposit(_ amount: Int64) -> Int64 {
    balance += amount
    return balance
  }

  func withdraw(_ amount: Int64) -> Bool {
    if balance < amount {
      return false
    }
    balance -= amount
    outgoing += amount
    return true
  }

  func getBalanceAt(_ timeAt: Int64) -> Int64? {
    if timeAt < createdAt {
      return nil
    }
    var result: Int64?
    for row in balanceHistory {
      if row.0 <= timeAt {
        result = row.1
      } else {
        break
      }
    }
    return result
  }
}

struct Cashback {
  var timestamp: Int64
  var accountId: String
  var amount: Int64
  var paymentId: String
}

final class Simulation: Harness {
  private static let cashbackDelay: Int64 = 24 * 60 * 60 * 1000

  private var accounts: [String: Account] = [:]
  private var paymentCounter: Int64 = 0
  private var pendingCashbacks: [Cashback] = []

  private func processCashbacks(_ timestamp: Int64) {
    while let first = pendingCashbacks.first, first.timestamp <= timestamp {
      let cashback = pendingCashbacks.removeFirst()
      if let account = accounts[cashback.accountId] {
        _ = account.deposit(cashback.amount)
        account.payments[cashback.paymentId] = "CASHBACK_RECEIVED"
        account.recordBalance(cashback.timestamp)
      }
    }
  }

  private func createAccount(_ timestamp: Int64, _ accountId: String) -> Bool {
    processCashbacks(timestamp)
    if accounts[accountId] != nil {
      return false
    }
    accounts[accountId] = Account(accountId: accountId, createdAt: timestamp)
    return true
  }

  private func deposit(_ timestamp: Int64, _ accountId: String, _ amount: Int64) -> Int64? {
    processCashbacks(timestamp)
    guard let account = accounts[accountId] else {
      return nil
    }
    let result = account.deposit(amount)
    account.recordBalance(timestamp)
    return result
  }

  private func transfer(
    _ timestamp: Int64,
    _ sourceId: String,
    _ targetId: String,
    _ amount: Int64
  ) -> Int64? {
    processCashbacks(timestamp)
    if sourceId == targetId {
      return nil
    }
    guard let source = accounts[sourceId], let target = accounts[targetId] else {
      return nil
    }
    if !source.withdraw(amount) {
      return nil
    }
    _ = target.deposit(amount)
    source.recordBalance(timestamp)
    target.recordBalance(timestamp)
    return source.balance
  }

  private func topSpenders(_ timestamp: Int64, _ n: Int64) -> [String] {
    processCashbacks(timestamp)
    var ids = Array(accounts.keys)
    ids.sort { left, right in
      let outgoingLeft = accounts[left]!.outgoing
      let outgoingRight = accounts[right]!.outgoing
      if outgoingLeft != outgoingRight {
        return outgoingRight < outgoingLeft
      }
      return left < right
    }
    if n < Int64(ids.count) {
      ids = Array(ids.prefix(Int(n)))
    }
    return ids.map { id in "\(id)(\(accounts[id]!.outgoing))" }
  }

  private func pay(_ timestamp: Int64, _ accountId: String, _ amount: Int64) -> String? {
    processCashbacks(timestamp)
    guard let account = accounts[accountId] else {
      return nil
    }
    if !account.withdraw(amount) {
      return nil
    }
    paymentCounter += 1
    let paymentId = "payment\(paymentCounter)"
    account.payments[paymentId] = "IN_PROGRESS"
    account.recordBalance(timestamp)
    pendingCashbacks.append(
      Cashback(
        timestamp: timestamp + Simulation.cashbackDelay,
        accountId: accountId,
        amount: (amount * 2) / 100,
        paymentId: paymentId
      )
    )
    return paymentId
  }

  private func getPaymentStatus(
    _ timestamp: Int64,
    _ accountId: String,
    _ payment: String
  ) -> String? {
    processCashbacks(timestamp)
    guard let account = accounts[accountId] else {
      return nil
    }
    return account.payments[payment]
  }

  private func mergeAccounts(_ timestamp: Int64, _ keepId: String, _ dropId: String) -> Bool {
    processCashbacks(timestamp)
    if keepId == dropId {
      return false
    }
    guard let keep = accounts[keepId], let drop = accounts[dropId] else {
      return false
    }
    keep.balance += drop.balance
    keep.outgoing += drop.outgoing
    for (paymentId, status) in drop.payments {
      keep.payments[paymentId] = status
    }
    keep.balanceHistory.append(contentsOf: drop.balanceHistory)
    keep.balanceHistory.sort { $0.0 < $1.0 }
    if drop.createdAt < keep.createdAt {
      keep.createdAt = drop.createdAt
    }
    keep.recordBalance(timestamp)
    for index in pendingCashbacks.indices where pendingCashbacks[index].accountId == dropId {
      pendingCashbacks[index].accountId = keepId
    }
    accounts[dropId] = nil
    return true
  }

  private func getBalance(_ timestamp: Int64, _ accountId: String, _ timeAt: Int64) -> Int64? {
    processCashbacks(timestamp)
    guard let account = accounts[accountId] else {
      return nil
    }
    return account.getBalanceAt(timeAt)
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    switch method {
    case "createAccount":
      return try createAccount(argI64(args, 0), argStr(args, 1))
    case "deposit":
      return try optI64(deposit(argI64(args, 0), argStr(args, 1), argI64(args, 2)))
    case "transfer":
      return try optI64(transfer(argI64(args, 0), argStr(args, 1), argStr(args, 2), argI64(args, 3)))
    case "topSpenders":
      return try topSpenders(argI64(args, 0), argI64(args, 1))
    case "pay":
      return try optStr(pay(argI64(args, 0), argStr(args, 1), argI64(args, 2)))
    case "getPaymentStatus":
      return try optStr(getPaymentStatus(argI64(args, 0), argStr(args, 1), argStr(args, 2)))
    case "mergeAccounts":
      return try mergeAccounts(argI64(args, 0), argStr(args, 1), argStr(args, 2))
    case "getBalance":
      return try optI64(getBalance(argI64(args, 0), argStr(args, 1), argI64(args, 2)))
    default:
      throw HarnessError.missingMethod(method)
    }
  }
}
