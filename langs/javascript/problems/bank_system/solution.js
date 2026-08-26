class Account {
  constructor(accountId, createdAt) {
    this.accountId = accountId;
    this.balance = 0;
    this.outgoing = 0;
    this.payments = {};
    this.createdAt = createdAt;
    this.balanceHistory = [[createdAt, 0]];
  }

  recordBalance(timestamp) {
    this.balanceHistory.push([timestamp, this.balance]);
  }

  deposit(amount) {
    this.balance += amount;
    return this.balance;
  }

  withdraw(amount) {
    if (this.balance < amount) return false;
    this.balance -= amount;
    this.outgoing += amount;
    return true;
  }

  getBalanceAt(timeAt) {
    if (timeAt < this.createdAt) return null;
    let result = null;
    for (const [ts, balance] of this.balanceHistory) {
      if (ts <= timeAt) result = balance;
      else break;
    }
    return result;
  }
}

class Simulation {
  constructor() {
    this.accounts = {};
    this.paymentCounter = 0;
    this.pendingCashbacks = [];
    this.CASHBACK_DELAY = 24 * 60 * 60 * 1000;
  }

  _process(timestamp) {
    while (this.pendingCashbacks.length && this.pendingCashbacks[0][0] <= timestamp) {
      const [cbTs, accountId, amount, paymentId] = this.pendingCashbacks.shift();
      if (this.accounts[accountId]) {
        const account = this.accounts[accountId];
        account.deposit(amount);
        account.payments[paymentId] = "CASHBACK_RECEIVED";
        account.recordBalance(cbTs);
      }
    }
  }

  createAccount(timestamp, accountId) {
    this._process(timestamp);
    if (this.accounts[accountId]) return false;
    this.accounts[accountId] = new Account(accountId, timestamp);
    return true;
  }

  deposit(timestamp, accountId, amount) {
    this._process(timestamp);
    if (!this.accounts[accountId]) return null;
    const account = this.accounts[accountId];
    const result = account.deposit(amount);
    account.recordBalance(timestamp);
    return result;
  }

  transfer(timestamp, sourceId, targetId, amount) {
    this._process(timestamp);
    if (!this.accounts[sourceId] || !this.accounts[targetId]) return null;
    if (sourceId === targetId) return null;
    const source = this.accounts[sourceId];
    const target = this.accounts[targetId];
    if (!source.withdraw(amount)) return null;
    target.deposit(amount);
    source.recordBalance(timestamp);
    target.recordBalance(timestamp);
    return source.balance;
  }

  topSpenders(timestamp, n) {
    this._process(timestamp);
    const ids = Object.keys(this.accounts).sort((a, b) => {
      const d = this.accounts[b].outgoing - this.accounts[a].outgoing;
      return d !== 0 ? d : a < b ? -1 : a > b ? 1 : 0;
    });
    return ids.slice(0, n).map((id) => `${id}(${this.accounts[id].outgoing})`);
  }

  pay(timestamp, accountId, amount) {
    this._process(timestamp);
    if (!this.accounts[accountId]) return null;
    const account = this.accounts[accountId];
    if (!account.withdraw(amount)) return null;
    this.paymentCounter += 1;
    const paymentId = `payment${this.paymentCounter}`;
    account.payments[paymentId] = "IN_PROGRESS";
    account.recordBalance(timestamp);
    this.pendingCashbacks.push([
      timestamp + this.CASHBACK_DELAY,
      accountId,
      Math.floor((amount * 2) / 100),
      paymentId,
    ]);
    return paymentId;
  }

  getPaymentStatus(timestamp, accountId, payment) {
    this._process(timestamp);
    if (!this.accounts[accountId]) return null;
    if (!(payment in this.accounts[accountId].payments)) return null;
    return this.accounts[accountId].payments[payment];
  }

  mergeAccounts(timestamp, keepId, dropId) {
    this._process(timestamp);
    if (keepId === dropId) return false;
    if (!this.accounts[keepId] || !this.accounts[dropId]) return false;
    const keep = this.accounts[keepId];
    const drop = this.accounts[dropId];
    keep.balance += drop.balance;
    keep.outgoing += drop.outgoing;
    Object.assign(keep.payments, drop.payments);
    keep.balanceHistory = keep.balanceHistory.concat(drop.balanceHistory);
    keep.balanceHistory.sort((a, b) => a[0] - b[0]);
    keep.createdAt = Math.min(keep.createdAt, drop.createdAt);
    keep.recordBalance(timestamp);
    this.pendingCashbacks = this.pendingCashbacks.map((row) =>
      row[1] === dropId ? [row[0], keepId, row[2], row[3]] : row,
    );
    delete this.accounts[dropId];
    return true;
  }

  getBalance(timestamp, accountId, timeAt) {
    this._process(timestamp);
    if (!this.accounts[accountId]) return null;
    return this.accounts[accountId].getBalanceAt(timeAt);
  }
}

module.exports = { Simulation };
