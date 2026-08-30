import java.util.List;

public class Simulation {
    public Simulation() {}

    /**
     * Create an account. Returns true if created, false if the id exists.
     */
    public boolean createAccount(int timestamp, String accountId) {
        return false;
    }

    /**
     * Add funds. Returns the new balance, or null if the account is missing.
     */
    public Integer deposit(int timestamp, String accountId, int amount) {
        return null;
    }

    /**
     * Move funds. Returns the source balance, or null if missing, same
     * account, or insufficient funds.
     */
    public Integer transfer(
            int timestamp, String sourceAccountId, String targetAccountId, int amount) {
        return null;
    }

    /**
     * Top accounts as {@code id(outgoing)}. Incoming does not count.
     * Zero-spend rows appear. Example: {@code ["acc1(500)", "acc2(0)"]}.
     */
    public List<String> topSpenders(int timestamp, int n) {
        return null;
    }

    /**
     * Withdraw now. Returns {@code paymentN}, or null if missing or
     * insufficient. Cashback is 2 percent after 86400000. Example:
     * {@code "payment1"}.
     */
    public String pay(int timestamp, String accountId, int amount) {
        return null;
    }

    /**
     * Returns {@code IN_PROGRESS} or {@code CASHBACK_RECEIVED}, or null
     * if the account or payment is wrong.
     */
    public String getPaymentStatus(int timestamp, String accountId, String payment) {
        return null;
    }

    /**
     * Merge {@code accountId2} into {@code accountId1}, then delete
     * {@code accountId2}. Moves balance, outgoing, payments, history,
     * and pending cashbacks. Returns false if either id is missing or
     * they are the same.
     */
    public boolean mergeAccounts(int timestamp, String accountId1, String accountId2) {
        return false;
    }

    /**
     * Balance at {@code timeAt} after cashbacks due at {@code timestamp}.
     */
    public Integer getBalance(int timestamp, String accountId, int timeAt) {
        return null;
    }
}
