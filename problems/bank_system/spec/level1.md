# Bank system level 1

Create accounts, deposit, transfer.

- `create_account(timestamp, account_id)` returns true if created, false if the id exists.
- `deposit(timestamp, account_id, amount)` returns the new balance, or null if missing.
- `transfer(timestamp, source, target, amount)` returns the source balance, or null if missing, same account, or insufficient funds.

Timestamps are unique integers. Operations are applied in call order.
