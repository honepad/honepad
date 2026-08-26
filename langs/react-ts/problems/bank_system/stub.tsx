class Simulation {
  constructor() {}
  createAccount(timestamp, account_id) { throw new Error('not implemented'); }
  deposit(timestamp, account_id, amount) { throw new Error('not implemented'); }
  transfer(timestamp, source_account_id, target_account_id, amount) { throw new Error('not implemented'); }
  topSpenders(timestamp, n) { throw new Error('not implemented'); }
  pay(timestamp, account_id, amount) { throw new Error('not implemented'); }
  getPaymentStatus(timestamp, account_id, payment) { throw new Error('not implemented'); }
  mergeAccounts(timestamp, account_id_1, account_id_2) { throw new Error('not implemented'); }
  getBalance(timestamp, account_id, time_at) { throw new Error('not implemented'); }
}
module.exports = { Simulation };
