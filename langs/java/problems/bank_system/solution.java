import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

class Account {
    String accountId;
    int balance = 0;
    int outgoing = 0;
    Map<String, String> payments = new LinkedHashMap<>();
    int createdAt;
    List<int[]> balanceHistory = new ArrayList<>();

    Account(String accountId, int createdAt) {
        this.accountId = accountId;
        this.createdAt = createdAt;
        balanceHistory.add(new int[] {createdAt, 0});
    }

    void recordBalance(int timestamp) {
        balanceHistory.add(new int[] {timestamp, balance});
    }

    int deposit(int amount) {
        balance += amount;
        return balance;
    }

    boolean withdraw(int amount) {
        if (balance < amount) {
            return false;
        }
        balance -= amount;
        outgoing += amount;
        return true;
    }

    Integer getBalanceAt(int timeAt) {
        if (timeAt < createdAt) {
            return null;
        }
        Integer result = null;
        for (int[] row : balanceHistory) {
            if (row[0] <= timeAt) {
                result = row[1];
            } else {
                break;
            }
        }
        return result;
    }
}

class Cashback {
    int timestamp;
    String accountId;
    int amount;
    String paymentId;

    Cashback(int timestamp, String accountId, int amount, String paymentId) {
        this.timestamp = timestamp;
        this.accountId = accountId;
        this.amount = amount;
        this.paymentId = paymentId;
    }
}

public class Simulation {
    static final int CASHBACK_DELAY = 24 * 60 * 60 * 1000;

    private final Map<String, Account> accounts = new LinkedHashMap<>();
    private int paymentCounter = 0;
    private final List<Cashback> pendingCashbacks = new ArrayList<>();

    public Simulation() {}

    private void processCashbacks(int timestamp) {
        while (!pendingCashbacks.isEmpty() && pendingCashbacks.get(0).timestamp <= timestamp) {
            Cashback cashback = pendingCashbacks.remove(0);
            Account account = accounts.get(cashback.accountId);
            if (account != null) {
                account.deposit(cashback.amount);
                account.payments.put(cashback.paymentId, "CASHBACK_RECEIVED");
                account.recordBalance(cashback.timestamp);
            }
        }
    }

    public boolean createAccount(int timestamp, String accountId) {
        processCashbacks(timestamp);
        if (accounts.containsKey(accountId)) {
            return false;
        }
        accounts.put(accountId, new Account(accountId, timestamp));
        return true;
    }

    public Integer deposit(int timestamp, String accountId, int amount) {
        processCashbacks(timestamp);
        Account account = accounts.get(accountId);
        if (account == null) {
            return null;
        }
        int result = account.deposit(amount);
        account.recordBalance(timestamp);
        return result;
    }

    public Integer transfer(int timestamp, String sourceAccountId, String targetAccountId, int amount) {
        processCashbacks(timestamp);
        Account source = accounts.get(sourceAccountId);
        Account target = accounts.get(targetAccountId);
        if (source == null || target == null) {
            return null;
        }
        if (sourceAccountId.equals(targetAccountId)) {
            return null;
        }
        if (!source.withdraw(amount)) {
            return null;
        }
        target.deposit(amount);
        source.recordBalance(timestamp);
        target.recordBalance(timestamp);
        return source.balance;
    }

    public List<String> topSpenders(int timestamp, int n) {
        processCashbacks(timestamp);
        List<String> ids = new ArrayList<>(accounts.keySet());
        ids.sort((a, b) -> {
            int d = Integer.compare(accounts.get(b).outgoing, accounts.get(a).outgoing);
            return d != 0 ? d : a.compareTo(b);
        });
        if (n < ids.size()) {
            ids = ids.subList(0, n);
        }
        List<String> out = new ArrayList<>();
        for (String id : ids) {
            out.add(id + "(" + accounts.get(id).outgoing + ")");
        }
        return out;
    }

    public String pay(int timestamp, String accountId, int amount) {
        processCashbacks(timestamp);
        Account account = accounts.get(accountId);
        if (account == null) {
            return null;
        }
        if (!account.withdraw(amount)) {
            return null;
        }
        paymentCounter += 1;
        String paymentId = "payment" + paymentCounter;
        account.payments.put(paymentId, "IN_PROGRESS");
        account.recordBalance(timestamp);
        pendingCashbacks.add(
            new Cashback(timestamp + CASHBACK_DELAY, accountId, (amount * 2) / 100, paymentId)
        );
        return paymentId;
    }

    public String getPaymentStatus(int timestamp, String accountId, String payment) {
        processCashbacks(timestamp);
        Account account = accounts.get(accountId);
        if (account == null) {
            return null;
        }
        return account.payments.get(payment);
    }

    public boolean mergeAccounts(int timestamp, String accountId1, String accountId2) {
        processCashbacks(timestamp);
        if (accountId1.equals(accountId2)) {
            return false;
        }
        Account account1 = accounts.get(accountId1);
        Account account2 = accounts.get(accountId2);
        if (account1 == null || account2 == null) {
            return false;
        }
        account1.balance += account2.balance;
        account1.outgoing += account2.outgoing;
        account1.payments.putAll(account2.payments);
        account1.balanceHistory.addAll(account2.balanceHistory);
        account1.balanceHistory.sort(Comparator.comparingInt(row -> row[0]));
        account1.createdAt = Math.min(account1.createdAt, account2.createdAt);
        account1.recordBalance(timestamp);
        for (Cashback cashback : pendingCashbacks) {
            if (accountId2.equals(cashback.accountId)) {
                cashback.accountId = accountId1;
            }
        }
        accounts.remove(accountId2);
        return true;
    }

    public Integer getBalance(int timestamp, String accountId, int timeAt) {
        processCashbacks(timestamp);
        Account account = accounts.get(accountId);
        if (account == null) {
            return null;
        }
        return account.getBalanceAt(timeAt);
    }
}
