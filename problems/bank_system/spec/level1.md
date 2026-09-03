# Bank system level 1

Create accounts, deposit, transfer.

- `create_account(timestamp, account_id)` returns true if created, false if the id exists.
- `deposit(timestamp, account_id, amount)` returns the new balance, or null if missing.
- `transfer(timestamp, source, target, amount)` returns the source balance, or null if missing, same account, or insufficient funds.

Call timestamps never decrease. Operations are applied in call order.

## Example

```
transfer(3, "non_existent", "acc2", 10) -> null
```

A missing source is null, same as a missing target.

```
deposit(3, "acc1", 100) -> 100
transfer(4, "acc1", "acc2", 100) -> 0
```

The whole balance may leave. The return is the new source balance, 0.
