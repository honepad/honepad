import std.algorithm : sort;
import std.array : array;
import std.conv : to;
import std.typecons : Nullable;

enum long cashbackDelay = 24L * 60L * 60L * 1000L;

struct BalancePoint
{
    long timestamp;
    long balance;
}

struct Cashback
{
    long timestamp;
    string accountId;
    long amount;
    string paymentId;
}

class Account
{
    string accountId;
    long balance;
    long outgoing;
    string[string] payments;
    long createdAt;
    BalancePoint[] balanceHistory;

    this(string accountId, long createdAt)
    {
        this.accountId = accountId;
        this.createdAt = createdAt;
        this.balanceHistory ~= BalancePoint(createdAt, 0);
    }

    void recordBalance(long timestamp)
    {
        balanceHistory ~= BalancePoint(timestamp, balance);
    }

    long depositAmount(long amount)
    {
        balance += amount;
        return balance;
    }

    bool withdraw(long amount)
    {
        if (balance < amount)
        {
            return false;
        }
        balance -= amount;
        outgoing += amount;
        return true;
    }

    Nullable!long getBalanceAt(long timeAt)
    {
        if (timeAt < createdAt)
        {
            return Nullable!long.init;
        }
        Nullable!long found;
        foreach (point; balanceHistory)
        {
            if (point.timestamp <= timeAt)
            {
                found = point.balance;
            }
            else
            {
                break;
            }
        }
        return found;
    }
}

class Simulation
{
    Account[string] accounts;
    int paymentCounter;
    Cashback[] pendingCashbacks;

    void processCashbacks(long timestamp)
    {
        while (pendingCashbacks.length > 0 && pendingCashbacks[0].timestamp <= timestamp)
        {
            auto cashback = pendingCashbacks[0];
            pendingCashbacks = pendingCashbacks[1 .. $];
            if (cashback.accountId in accounts)
            {
                auto account = accounts[cashback.accountId];
                account.depositAmount(cashback.amount);
                account.payments[cashback.paymentId] = "CASHBACK_RECEIVED";
                account.recordBalance(cashback.timestamp);
            }
        }
    }

    bool createAccount(long timestamp, string accountId)
    {
        processCashbacks(timestamp);
        if (accountId in accounts)
        {
            return false;
        }
        accounts[accountId] = new Account(accountId, timestamp);
        return true;
    }

    Nullable!long deposit(long timestamp, string accountId, long amount)
    {
        processCashbacks(timestamp);
        if (accountId !in accounts)
        {
            return Nullable!long.init;
        }
        auto account = accounts[accountId];
        auto value = account.depositAmount(amount);
        account.recordBalance(timestamp);
        return Nullable!long(value);
    }

    Nullable!long transfer(
        long timestamp,
        string sourceAccountId,
        string targetAccountId,
        long amount
    )
    {
        processCashbacks(timestamp);
        if (sourceAccountId !in accounts || targetAccountId !in accounts)
        {
            return Nullable!long.init;
        }
        if (sourceAccountId == targetAccountId)
        {
            return Nullable!long.init;
        }
        auto source = accounts[sourceAccountId];
        auto target = accounts[targetAccountId];
        if (!source.withdraw(amount))
        {
            return Nullable!long.init;
        }
        target.depositAmount(amount);
        source.recordBalance(timestamp);
        target.recordBalance(timestamp);
        return Nullable!long(source.balance);
    }

    string[] topSpenders(long timestamp, long n)
    {
        processCashbacks(timestamp);
        auto ids = accounts.keys.array;
        ids.sort!((a, b) {
            if (accounts[a].outgoing != accounts[b].outgoing)
            {
                return accounts[a].outgoing > accounts[b].outgoing;
            }
            return a < b;
        });
        auto take = n < ids.length ? cast(size_t) n : ids.length;
        string[] result;
        foreach (id; ids[0 .. take])
        {
            result ~= id ~ "(" ~ accounts[id].outgoing.to!string ~ ")";
        }
        return result;
    }

    Nullable!string pay(long timestamp, string accountId, long amount)
    {
        processCashbacks(timestamp);
        if (accountId !in accounts)
        {
            return Nullable!string.init;
        }
        auto account = accounts[accountId];
        if (!account.withdraw(amount))
        {
            return Nullable!string.init;
        }
        paymentCounter += 1;
        auto paymentId = "payment" ~ paymentCounter.to!string;
        account.payments[paymentId] = "IN_PROGRESS";
        account.recordBalance(timestamp);
        auto cashbackAmount = (amount * 2) / 100;
        pendingCashbacks ~= Cashback(
            timestamp + cashbackDelay,
            accountId,
            cashbackAmount,
            paymentId
        );
        return Nullable!string(paymentId);
    }

    Nullable!string getPaymentStatus(long timestamp, string accountId, string payment)
    {
        processCashbacks(timestamp);
        if (accountId !in accounts)
        {
            return Nullable!string.init;
        }
        auto account = accounts[accountId];
        if (payment !in account.payments)
        {
            return Nullable!string.init;
        }
        return Nullable!string(account.payments[payment]);
    }

    bool mergeAccounts(long timestamp, string accountId1, string accountId2)
    {
        processCashbacks(timestamp);
        if (accountId1 == accountId2)
        {
            return false;
        }
        if (accountId1 !in accounts || accountId2 !in accounts)
        {
            return false;
        }
        auto account1 = accounts[accountId1];
        auto account2 = accounts[accountId2];
        account1.balance += account2.balance;
        account1.outgoing += account2.outgoing;
        foreach (paymentId, status; account2.payments)
        {
            account1.payments[paymentId] = status;
        }
        account1.balanceHistory ~= account2.balanceHistory;
        account1.balanceHistory.sort!((a, b) => a.timestamp < b.timestamp);
        if (account2.createdAt < account1.createdAt)
        {
            account1.createdAt = account2.createdAt;
        }
        account1.recordBalance(timestamp);
        foreach (ref cashback; pendingCashbacks)
        {
            if (cashback.accountId == accountId2)
            {
                cashback.accountId = accountId1;
            }
        }
        accounts.remove(accountId2);
        return true;
    }

    Nullable!long getBalance(long timestamp, string accountId, long timeAt)
    {
        processCashbacks(timestamp);
        if (accountId !in accounts)
        {
            return Nullable!long.init;
        }
        return accounts[accountId].getBalanceAt(timeAt);
    }
}
