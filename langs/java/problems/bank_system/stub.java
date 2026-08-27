import java.util.List;

public class Simulation {
    public Simulation() {}

    public boolean createAccount(int timestamp, String accountId) {
        return false;
    }

    public Integer deposit(int timestamp, String accountId, int amount) {
        return null;
    }

    public Integer transfer(
            int timestamp, String sourceAccountId, String targetAccountId, int amount) {
        return null;
    }

    public List<String> topSpenders(int timestamp, int n) {
        return null;
    }

    public String pay(int timestamp, String accountId, int amount) {
        return null;
    }

    public String getPaymentStatus(int timestamp, String accountId, String payment) {
        return null;
    }

    public boolean mergeAccounts(int timestamp, String accountId1, String accountId2) {
        return false;
    }

    public Integer getBalance(int timestamp, String accountId, int timeAt) {
        return null;
    }
}
