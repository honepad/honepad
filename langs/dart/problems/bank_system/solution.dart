class Account {
  Account(this.accountId, this.createdAt) {
    balanceHistory.add([createdAt, 0]);
  }

  final String accountId;
  int balance = 0;
  int outgoing = 0;
  final Map<String, String> payments = {};
  int createdAt;
  final List<List<int>> balanceHistory = [];

  void recordBalance(int timestamp) {
    balanceHistory.add([timestamp, balance]);
  }

  int deposit(int amount) {
    balance += amount;
    return balance;
  }

  bool withdraw(int amount) {
    if (balance < amount) {
      return false;
    }
    balance -= amount;
    outgoing += amount;
    return true;
  }

  int? getBalanceAt(int timeAt) {
    if (timeAt < createdAt) {
      return null;
    }
    int? result;
    for (final row in balanceHistory) {
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
  Cashback(this.timestamp, this.accountId, this.amount, this.paymentId);

  final int timestamp;
  String accountId;
  final int amount;
  final String paymentId;
}

class Simulation {
  static const int cashbackDelay = 24 * 60 * 60 * 1000;

  final Map<String, Account> accounts = {};
  int paymentCounter = 0;
  final List<Cashback> pendingCashbacks = [];

  void _processCashbacks(int timestamp) {
    while (pendingCashbacks.isNotEmpty &&
        pendingCashbacks.first.timestamp <= timestamp) {
      final cashback = pendingCashbacks.removeAt(0);
      final account = accounts[cashback.accountId];
      if (account != null) {
        account.deposit(cashback.amount);
        account.payments[cashback.paymentId] = 'CASHBACK_RECEIVED';
        account.recordBalance(cashback.timestamp);
      }
    }
  }

  bool createAccount(int timestamp, String accountId) {
    _processCashbacks(timestamp);
    if (accounts.containsKey(accountId)) {
      return false;
    }
    accounts[accountId] = Account(accountId, timestamp);
    return true;
  }

  int? deposit(int timestamp, String accountId, int amount) {
    _processCashbacks(timestamp);
    final account = accounts[accountId];
    if (account == null) {
      return null;
    }
    final result = account.deposit(amount);
    account.recordBalance(timestamp);
    return result;
  }

  int? transfer(
    int timestamp,
    String sourceAccountId,
    String targetAccountId,
    int amount,
  ) {
    _processCashbacks(timestamp);
    final source = accounts[sourceAccountId];
    final target = accounts[targetAccountId];
    if (source == null || target == null) {
      return null;
    }
    if (sourceAccountId == targetAccountId) {
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

  List<String> topSpenders(int timestamp, int n) {
    _processCashbacks(timestamp);
    final ids = accounts.keys.toList();
    ids.sort((a, b) {
      final d = accounts[b]!.outgoing.compareTo(accounts[a]!.outgoing);
      return d != 0 ? d : a.compareTo(b);
    });
    final limit = n < ids.length ? n : ids.length;
    return [
      for (final id in ids.sublist(0, limit)) '${id}(${accounts[id]!.outgoing})',
    ];
  }

  String? pay(int timestamp, String accountId, int amount) {
    _processCashbacks(timestamp);
    final account = accounts[accountId];
    if (account == null) {
      return null;
    }
    if (!account.withdraw(amount)) {
      return null;
    }
    paymentCounter += 1;
    final paymentId = 'payment$paymentCounter';
    account.payments[paymentId] = 'IN_PROGRESS';
    account.recordBalance(timestamp);
    pendingCashbacks.add(Cashback(
      timestamp + cashbackDelay,
      accountId,
      (amount * 2) ~/ 100,
      paymentId,
    ));
    return paymentId;
  }

  String? getPaymentStatus(int timestamp, String accountId, String payment) {
    _processCashbacks(timestamp);
    final account = accounts[accountId];
    if (account == null) {
      return null;
    }
    return account.payments[payment];
  }

  bool mergeAccounts(int timestamp, String accountId1, String accountId2) {
    _processCashbacks(timestamp);
    if (accountId1 == accountId2) {
      return false;
    }
    final account1 = accounts[accountId1];
    final account2 = accounts[accountId2];
    if (account1 == null || account2 == null) {
      return false;
    }
    account1.balance += account2.balance;
    account1.outgoing += account2.outgoing;
    account1.payments.addAll(account2.payments);
    account1.balanceHistory.addAll(account2.balanceHistory);
    account1.balanceHistory.sort((a, b) => a[0].compareTo(b[0]));
    account1.createdAt = account1.createdAt < account2.createdAt
        ? account1.createdAt
        : account2.createdAt;
    account1.recordBalance(timestamp);
    for (final cashback in pendingCashbacks) {
      if (cashback.accountId == accountId2) {
        cashback.accountId = accountId1;
      }
    }
    accounts.remove(accountId2);
    return true;
  }

  int? getBalance(int timestamp, String accountId, int timeAt) {
    _processCashbacks(timestamp);
    final account = accounts[accountId];
    if (account == null) {
      return null;
    }
    return account.getBalanceAt(timeAt);
  }
}
