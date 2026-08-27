class Simulation {
    static final long CASHBACK_DELAY = 24L * 60L * 60L * 1000L

    private final Map<String, Account> accounts = new LinkedHashMap<>()
    private int paymentCounter = 0
    private final List<Cashback> pendingCashbacks = []

    private void processCashbacks(long timestamp) {
        while (!pendingCashbacks.isEmpty() && pendingCashbacks[0].timestamp <= timestamp) {
            Cashback cashback = pendingCashbacks.remove(0)
            Account account = accounts[cashback.accountId]
            if (account != null) {
                account.deposit(cashback.amount)
                account.payments[cashback.paymentId] = 'CASHBACK_RECEIVED'
                account.recordBalance(cashback.timestamp)
            }
        }
    }

    boolean createAccount(long timestamp, String accountId) {
        processCashbacks(timestamp)
        if (accounts.containsKey(accountId)) {
            return false
        }
        accounts[accountId] = new Account(accountId, timestamp)
        return true
    }

    Long deposit(long timestamp, String accountId, long amount) {
        processCashbacks(timestamp)
        Account account = accounts[accountId]
        if (account == null) {
            return null
        }
        long result = account.deposit(amount)
        account.recordBalance(timestamp)
        return result
    }

    Long transfer(long timestamp, String sourceAccountId, String targetAccountId, long amount) {
        processCashbacks(timestamp)
        Account source = accounts[sourceAccountId]
        Account target = accounts[targetAccountId]
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

    List<String> topSpenders(long timestamp, long n) {
        processCashbacks(timestamp)
        List<String> ids = new ArrayList<>(accounts.keySet())
        ids.sort { a, b ->
            int d = Long.compare(accounts[b].outgoing, accounts[a].outgoing)
            d != 0 ? d : a <=> b
        }
        int limit = Math.min(n as int, ids.size())
        ids = ids.subList(0, limit)
        ids.collect { id -> "${id}(${accounts[id].outgoing})".toString() }
    }

    String pay(long timestamp, String accountId, long amount) {
        processCashbacks(timestamp)
        Account account = accounts[accountId]
        if (account == null) {
            return null
        }
        if (!account.withdraw(amount)) {
            return null
        }
        paymentCounter += 1
        String paymentId = "payment${paymentCounter}"
        account.payments[paymentId] = 'IN_PROGRESS'
        account.recordBalance(timestamp)
        pendingCashbacks.add(new Cashback(
            timestamp + CASHBACK_DELAY,
            accountId,
            (amount * 2).intdiv(100),
            paymentId,
        ))
        return paymentId
    }

    String getPaymentStatus(long timestamp, String accountId, String payment) {
        processCashbacks(timestamp)
        Account account = accounts[accountId]
        if (account == null) {
            return null
        }
        return account.payments[payment]
    }

    boolean mergeAccounts(long timestamp, String accountId1, String accountId2) {
        processCashbacks(timestamp)
        if (accountId1 == accountId2) {
            return false
        }
        Account account1 = accounts[accountId1]
        Account account2 = accounts[accountId2]
        if (account1 == null || account2 == null) {
            return false
        }
        account1.balance += account2.balance
        account1.outgoing += account2.outgoing
        account1.payments.putAll(account2.payments)
        account1.balanceHistory.addAll(account2.balanceHistory)
        account1.balanceHistory.sort { a, b -> Long.compare(a[0], b[0]) }
        account1.createdAt = Math.min(account1.createdAt, account2.createdAt)
        account1.recordBalance(timestamp)
        pendingCashbacks.each { cashback ->
            if (cashback.accountId == accountId2) {
                cashback.accountId = accountId1
            }
        }
        accounts.remove(accountId2)
        return true
    }

    Long getBalance(long timestamp, String accountId, long timeAt) {
        processCashbacks(timestamp)
        Account account = accounts[accountId]
        if (account == null) {
            return null
        }
        return account.getBalanceAt(timeAt)
    }
}

class Account {
    String accountId
    long balance = 0
    long outgoing = 0
    Map<String, String> payments = new LinkedHashMap<>()
    long createdAt
    List<long[]> balanceHistory = []

    Account(String accountId, long createdAt) {
        this.accountId = accountId
        this.createdAt = createdAt
        balanceHistory.add([createdAt, 0L] as long[])
    }

    void recordBalance(long timestamp) {
        balanceHistory.add([timestamp, balance] as long[])
    }

    long deposit(long amount) {
        balance += amount
        return balance
    }

    boolean withdraw(long amount) {
        if (balance < amount) {
            return false
        }
        balance -= amount
        outgoing += amount
        return true
    }

    Long getBalanceAt(long timeAt) {
        if (timeAt < createdAt) {
            return null
        }
        Long result = null
        for (long[] row : balanceHistory) {
            if (row[0] <= timeAt) {
                result = row[1]
            } else {
                break
            }
        }
        return result
    }
}

class Cashback {
    long timestamp
    String accountId
    long amount
    String paymentId

    Cashback(long timestamp, String accountId, long amount, String paymentId) {
        this.timestamp = timestamp
        this.accountId = accountId
        this.amount = amount
        this.paymentId = paymentId
    }
}
