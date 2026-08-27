class Account(val accountId: String, var createdAt: Int) {
    var balance = 0
    var outgoing = 0
    val payments = LinkedHashMap<String, String>()
    val balanceHistory = ArrayList<IntArray>()

    init {
        balanceHistory.add(intArrayOf(createdAt, 0))
    }

    fun recordBalance(timestamp: Int) {
        balanceHistory.add(intArrayOf(timestamp, balance))
    }

    fun deposit(amount: Int): Int {
        balance += amount
        return balance
    }

    fun withdraw(amount: Int): Boolean {
        if (balance < amount) {
            return false
        }
        balance -= amount
        outgoing += amount
        return true
    }

    fun getBalanceAt(timeAt: Int): Int? {
        if (timeAt < createdAt) {
            return null
        }
        var result: Int? = null
        for (row in balanceHistory) {
            if (row[0] <= timeAt) {
                result = row[1]
            } else {
                break
            }
        }
        return result
    }
}

class Cashback(
    val timestamp: Int,
    var accountId: String,
    val amount: Int,
    val paymentId: String,
)

class Simulation {
    companion object {
        const val CASHBACK_DELAY = 24 * 60 * 60 * 1000
    }

    private val accounts = LinkedHashMap<String, Account>()
    private var paymentCounter = 0
    private val pendingCashbacks = ArrayList<Cashback>()

    private fun processCashbacks(timestamp: Int) {
        while (pendingCashbacks.isNotEmpty() && pendingCashbacks[0].timestamp <= timestamp) {
            val cashback = pendingCashbacks.removeAt(0)
            val account = accounts[cashback.accountId]
            if (account != null) {
                account.deposit(cashback.amount)
                account.payments[cashback.paymentId] = "CASHBACK_RECEIVED"
                account.recordBalance(cashback.timestamp)
            }
        }
    }

    fun createAccount(timestamp: Int, accountId: String): Boolean {
        processCashbacks(timestamp)
        if (accounts.containsKey(accountId)) {
            return false
        }
        accounts[accountId] = Account(accountId, timestamp)
        return true
    }

    fun deposit(timestamp: Int, accountId: String, amount: Int): Int? {
        processCashbacks(timestamp)
        val account = accounts[accountId] ?: return null
        val result = account.deposit(amount)
        account.recordBalance(timestamp)
        return result
    }

    fun transfer(
        timestamp: Int,
        sourceAccountId: String,
        targetAccountId: String,
        amount: Int,
    ): Int? {
        processCashbacks(timestamp)
        val source = accounts[sourceAccountId]
        val target = accounts[targetAccountId]
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
        return source.balance
    }

    fun topSpenders(timestamp: Int, n: Int): List<String> {
        processCashbacks(timestamp)
        val ids = ArrayList(accounts.keys)
        ids.sortWith { a, b ->
            val d = accounts[b]!!.outgoing.compareTo(accounts[a]!!.outgoing)
            if (d != 0) d else a.compareTo(b)
        }
        val cut = if (n < ids.size) ids.subList(0, n) else ids
        val out = ArrayList<String>()
        for (id in cut) {
            out.add(id + "(" + accounts[id]!!.outgoing + ")")
        }
        return out
    }

    fun pay(timestamp: Int, accountId: String, amount: Int): String? {
        processCashbacks(timestamp)
        val account = accounts[accountId] ?: return null
        if (!account.withdraw(amount)) {
            return null
        }
        paymentCounter += 1
        val paymentId = "payment$paymentCounter"
        account.payments[paymentId] = "IN_PROGRESS"
        account.recordBalance(timestamp)
        pendingCashbacks.add(
            Cashback(timestamp + CASHBACK_DELAY, accountId, (amount * 2) / 100, paymentId),
        )
        return paymentId
    }

    fun getPaymentStatus(timestamp: Int, accountId: String, payment: String): String? {
        processCashbacks(timestamp)
        val account = accounts[accountId] ?: return null
        return account.payments[payment]
    }

    fun mergeAccounts(timestamp: Int, accountId1: String, accountId2: String): Boolean {
        processCashbacks(timestamp)
        if (accountId1 == accountId2) {
            return false
        }
        val account1 = accounts[accountId1]
        val account2 = accounts[accountId2]
        if (account1 == null || account2 == null) {
            return false
        }
        account1.balance += account2.balance
        account1.outgoing += account2.outgoing
        account1.payments.putAll(account2.payments)
        account1.balanceHistory.addAll(account2.balanceHistory)
        account1.balanceHistory.sortBy { it[0] }
        account1.createdAt = minOf(account1.createdAt, account2.createdAt)
        account1.recordBalance(timestamp)
        for (cashback in pendingCashbacks) {
            if (accountId2 == cashback.accountId) {
                cashback.accountId = accountId1
            }
        }
        accounts.remove(accountId2)
        return true
    }

    fun getBalance(timestamp: Int, accountId: String, timeAt: Int): Int? {
        processCashbacks(timestamp)
        val account = accounts[accountId] ?: return null
        return account.getBalanceAt(timeAt)
    }
}
