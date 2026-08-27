import java.util.{ArrayList, Comparator, LinkedHashMap, List => JList, Map => JMap}

class Account(var accountId: String, var createdAt: Int) {
  var balance: Int = 0
  var outgoing: Int = 0
  val payments: JMap[String, String] = new LinkedHashMap[String, String]()
  val balanceHistory: JList[Array[Int]] = new ArrayList[Array[Int]]()
  balanceHistory.add(Array(createdAt, 0))

  def recordBalance(timestamp: Int): Unit = {
    balanceHistory.add(Array(timestamp, balance))
  }

  def deposit(amount: Int): Int = {
    balance += amount
    balance
  }

  def withdraw(amount: Int): Boolean = {
    if (balance < amount) {
      return false
    }
    balance -= amount
    outgoing += amount
    true
  }

  def getBalanceAt(timeAt: Int): Integer = {
    if (timeAt < createdAt) {
      return null
    }
    var result: Integer = null
    var i = 0
    while (i < balanceHistory.size()) {
      val row = balanceHistory.get(i)
      if (row(0) <= timeAt) {
        result = Int.box(row(1))
      } else {
        return result
      }
      i += 1
    }
    result
  }
}

class Cashback(var timestamp: Int, var accountId: String, val amount: Int, val paymentId: String)

class Simulation {
  val CASHBACK_DELAY: Int = 24 * 60 * 60 * 1000
  private val accounts: JMap[String, Account] = new LinkedHashMap[String, Account]()
  private var paymentCounter: Int = 0
  private val pendingCashbacks: JList[Cashback] = new ArrayList[Cashback]()

  private def processCashbacks(timestamp: Int): Unit = {
    while (!pendingCashbacks.isEmpty && pendingCashbacks.get(0).timestamp <= timestamp) {
      val cashback = pendingCashbacks.remove(0)
      val account = accounts.get(cashback.accountId)
      if (account != null) {
        account.deposit(cashback.amount)
        account.payments.put(cashback.paymentId, "CASHBACK_RECEIVED")
        account.recordBalance(cashback.timestamp)
      }
    }
  }

  def createAccount(timestamp: Int, accountId: String): Boolean = {
    processCashbacks(timestamp)
    if (accounts.containsKey(accountId)) {
      return false
    }
    accounts.put(accountId, new Account(accountId, timestamp))
    true
  }

  def deposit(timestamp: Int, accountId: String, amount: Int): Integer = {
    processCashbacks(timestamp)
    val account = accounts.get(accountId)
    if (account == null) {
      return null
    }
    val result = account.deposit(amount)
    account.recordBalance(timestamp)
    Int.box(result)
  }

  def transfer(
      timestamp: Int,
      sourceAccountId: String,
      targetAccountId: String,
      amount: Int
  ): Integer = {
    processCashbacks(timestamp)
    val source = accounts.get(sourceAccountId)
    val target = accounts.get(targetAccountId)
    if (source == null || target == null) {
      return null
    }
    if (sourceAccountId == targetAccountId) {
      return null
    }
    if (!source.withdraw(amount)) {
      return null
    }
    target.deposit(amount)
    source.recordBalance(timestamp)
    target.recordBalance(timestamp)
    Int.box(source.balance)
  }

  def topSpenders(timestamp: Int, n: Int): JList[String] = {
    processCashbacks(timestamp)
    val ids = new ArrayList[String](accounts.keySet())
    ids.sort((a: String, b: String) => {
      val d = Integer.compare(accounts.get(b).outgoing, accounts.get(a).outgoing)
      if (d != 0) d else a.compareTo(b)
    })
    val sliced = if (n < ids.size()) ids.subList(0, n) else ids
    val out = new ArrayList[String]()
    val it = sliced.iterator()
    while (it.hasNext) {
      val id = it.next()
      out.add(id + "(" + accounts.get(id).outgoing + ")")
    }
    out
  }

  def pay(timestamp: Int, accountId: String, amount: Int): String = {
    processCashbacks(timestamp)
    val account = accounts.get(accountId)
    if (account == null) {
      return null
    }
    if (!account.withdraw(amount)) {
      return null
    }
    paymentCounter += 1
    val paymentId = "payment" + paymentCounter
    account.payments.put(paymentId, "IN_PROGRESS")
    account.recordBalance(timestamp)
    pendingCashbacks.add(
      new Cashback(timestamp + CASHBACK_DELAY, accountId, (amount * 2) / 100, paymentId)
    )
    paymentId
  }

  def getPaymentStatus(timestamp: Int, accountId: String, payment: String): String = {
    processCashbacks(timestamp)
    val account = accounts.get(accountId)
    if (account == null) {
      return null
    }
    account.payments.get(payment)
  }

  def mergeAccounts(timestamp: Int, accountId1: String, accountId2: String): Boolean = {
    processCashbacks(timestamp)
    if (accountId1 == accountId2) {
      return false
    }
    val account1 = accounts.get(accountId1)
    val account2 = accounts.get(accountId2)
    if (account1 == null || account2 == null) {
      return false
    }
    account1.balance += account2.balance
    account1.outgoing += account2.outgoing
    account1.payments.putAll(account2.payments)
    account1.balanceHistory.addAll(account2.balanceHistory)
    account1.balanceHistory.sort(Comparator.comparingInt((row: Array[Int]) => row(0)))
    account1.createdAt = Math.min(account1.createdAt, account2.createdAt)
    account1.recordBalance(timestamp)
    var i = 0
    while (i < pendingCashbacks.size()) {
      val cashback = pendingCashbacks.get(i)
      if (accountId2 == cashback.accountId) {
        cashback.accountId = accountId1
      }
      i += 1
    }
    accounts.remove(accountId2)
    true
  }

  def getBalance(timestamp: Int, accountId: String, timeAt: Int): Integer = {
    processCashbacks(timestamp)
    val account = accounts.get(accountId)
    if (account == null) {
      return null
    }
    account.getBalanceAt(timeAt)
  }
}
