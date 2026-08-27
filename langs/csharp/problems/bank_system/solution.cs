class Account
{
    public string AccountId;
    public int Balance;
    public int Outgoing;
    public Dictionary<string, string> Payments = new();
    public int CreatedAt;
    public List<int[]> BalanceHistory = new();

    public Account(string accountId, int createdAt)
    {
        AccountId = accountId;
        CreatedAt = createdAt;
        BalanceHistory.Add(new[] { createdAt, 0 });
    }

    public void RecordBalance(int timestamp)
    {
        BalanceHistory.Add(new[] { timestamp, Balance });
    }

    public int Deposit(int amount)
    {
        Balance += amount;
        return Balance;
    }

    public bool Withdraw(int amount)
    {
        if (Balance < amount)
        {
            return false;
        }
        Balance -= amount;
        Outgoing += amount;
        return true;
    }

    public int? GetBalanceAt(int timeAt)
    {
        if (timeAt < CreatedAt)
        {
            return null;
        }
        int? result = null;
        foreach (int[] row in BalanceHistory)
        {
            if (row[0] <= timeAt)
            {
                result = row[1];
            }
            else
            {
                break;
            }
        }
        return result;
    }
}

class Cashback
{
    public int Timestamp;
    public string AccountId;
    public int Amount;
    public string PaymentId;

    public Cashback(int timestamp, string accountId, int amount, string paymentId)
    {
        Timestamp = timestamp;
        AccountId = accountId;
        Amount = amount;
        PaymentId = paymentId;
    }
}

public class Simulation
{
    const int CashbackDelay = 24 * 60 * 60 * 1000;

    readonly Dictionary<string, Account> accounts = new();
    int paymentCounter;
    readonly List<Cashback> pendingCashbacks = new();

    public Simulation() { }

    void ProcessCashbacks(int timestamp)
    {
        while (pendingCashbacks.Count > 0 && pendingCashbacks[0].Timestamp <= timestamp)
        {
            Cashback cashback = pendingCashbacks[0];
            pendingCashbacks.RemoveAt(0);
            if (accounts.TryGetValue(cashback.AccountId, out Account? account))
            {
                account.Deposit(cashback.Amount);
                account.Payments[cashback.PaymentId] = "CASHBACK_RECEIVED";
                account.RecordBalance(cashback.Timestamp);
            }
        }
    }

    public bool CreateAccount(int timestamp, string accountId)
    {
        ProcessCashbacks(timestamp);
        if (accounts.ContainsKey(accountId))
        {
            return false;
        }
        accounts[accountId] = new Account(accountId, timestamp);
        return true;
    }

    public int? Deposit(int timestamp, string accountId, int amount)
    {
        ProcessCashbacks(timestamp);
        if (!accounts.TryGetValue(accountId, out Account? account))
        {
            return null;
        }
        int result = account.Deposit(amount);
        account.RecordBalance(timestamp);
        return result;
    }

    public int? Transfer(int timestamp, string sourceAccountId, string targetAccountId, int amount)
    {
        ProcessCashbacks(timestamp);
        if (
            !accounts.TryGetValue(sourceAccountId, out Account? source)
            || !accounts.TryGetValue(targetAccountId, out Account? target)
        )
        {
            return null;
        }
        if (sourceAccountId == targetAccountId)
        {
            return null;
        }
        if (!source.Withdraw(amount))
        {
            return null;
        }
        target.Deposit(amount);
        source.RecordBalance(timestamp);
        target.RecordBalance(timestamp);
        return source.Balance;
    }

    public List<string> TopSpenders(int timestamp, int n)
    {
        ProcessCashbacks(timestamp);
        List<string> ids = accounts.Keys.ToList();
        ids.Sort(
            (a, b) =>
            {
                int d = accounts[b].Outgoing.CompareTo(accounts[a].Outgoing);
                return d != 0 ? d : string.CompareOrdinal(a, b);
            }
        );
        if (n < ids.Count)
        {
            ids = ids.GetRange(0, n);
        }
        return ids.Select(id => id + "(" + accounts[id].Outgoing + ")").ToList();
    }

    public string? Pay(int timestamp, string accountId, int amount)
    {
        ProcessCashbacks(timestamp);
        if (!accounts.TryGetValue(accountId, out Account? account))
        {
            return null;
        }
        if (!account.Withdraw(amount))
        {
            return null;
        }
        paymentCounter += 1;
        string paymentId = "payment" + paymentCounter;
        account.Payments[paymentId] = "IN_PROGRESS";
        account.RecordBalance(timestamp);
        pendingCashbacks.Add(
            new Cashback(timestamp + CashbackDelay, accountId, (amount * 2) / 100, paymentId)
        );
        return paymentId;
    }

    public string? GetPaymentStatus(int timestamp, string accountId, string payment)
    {
        ProcessCashbacks(timestamp);
        if (!accounts.TryGetValue(accountId, out Account? account))
        {
            return null;
        }
        return account.Payments.TryGetValue(payment, out string? status) ? status : null;
    }

    public bool MergeAccounts(int timestamp, string accountId1, string accountId2)
    {
        ProcessCashbacks(timestamp);
        if (accountId1 == accountId2)
        {
            return false;
        }
        if (
            !accounts.TryGetValue(accountId1, out Account? account1)
            || !accounts.TryGetValue(accountId2, out Account? account2)
        )
        {
            return false;
        }
        account1.Balance += account2.Balance;
        account1.Outgoing += account2.Outgoing;
        foreach (KeyValuePair<string, string> pair in account2.Payments)
        {
            account1.Payments[pair.Key] = pair.Value;
        }
        account1.BalanceHistory.AddRange(account2.BalanceHistory);
        account1.BalanceHistory.Sort((a, b) => a[0].CompareTo(b[0]));
        account1.CreatedAt = Math.Min(account1.CreatedAt, account2.CreatedAt);
        account1.RecordBalance(timestamp);
        foreach (Cashback cashback in pendingCashbacks)
        {
            if (cashback.AccountId == accountId2)
            {
                cashback.AccountId = accountId1;
            }
        }
        accounts.Remove(accountId2);
        return true;
    }

    public int? GetBalance(int timestamp, string accountId, int timeAt)
    {
        ProcessCashbacks(timestamp);
        if (!accounts.TryGetValue(accountId, out Account? account))
        {
            return null;
        }
        return account.GetBalanceAt(timeAt);
    }
}
