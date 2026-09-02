# Bank system level 4

`merge_accounts(timestamp, keep, drop)` moves balance, outgoing,
payments, history, and pending cashbacks from `drop` onto `keep`, then
deletes `drop`. Returns false if either id is missing or they are the
same.

After a merge, payment ids still work on `keep`. `top_spenders` no
longer lists `drop`. Outgoing is the sum.

`get_balance(timestamp, account_id, time_at)` returns the balance as
of `time_at`. Apply cashbacks that are due at `timestamp` first. Then
read the last recorded balance at or before `time_at`. Missing account
returns null.

## Example

```
create_account(1, "acc1") -> true
deposit(2, "acc1", 1000) -> 1000
pay(3, "acc1", 500) -> "payment1"
create_account(4, "acc2") -> true
merge_accounts(5, "acc2", "acc1") -> true
get_payment_status(6, "acc2", "payment1") -> "IN_PROGRESS"
get_payment_status(86400003, "acc2", "payment1") -> "CASHBACK_RECEIVED"
deposit(86400005, "acc2", 0) -> 510
```

The pending 10 cashback moved with the payment. acc1 is gone.

```
create_account(1, "acc1") -> true
deposit(2, "acc1", 1000) -> 1000
pay(3, "acc1", 500) -> "payment1"
create_account(4, "acc2") -> true
deposit(5, "acc2", 2000) -> 2000
pay(6, "acc2", 800) -> "payment2"
merge_accounts(7, "acc1", "acc2") -> true
top_spenders(8, 1) -> ["acc1(1300)"]
```

Outgoing on keep is 500 + 800.

```
create_account(1, "acc1") -> true
deposit(2, "acc1", 1000) -> 1000
pay(3, "acc1", 300) -> "payment1"
get_balance(4, "acc1", 3) -> 700
get_balance(86400005, "acc1", 86400002) -> 700
get_balance(86400005, "acc1", 86400003) -> 706
```

Pay at 3 leaves 700. Cashback 6 is due at 86400003. A query whose
`time_at` is still 86400002 does not include it.

```
merge_accounts(2, "acc1", "acc2") -> false
```

That call is false when acc1 is missing. Same id is also false.

```
create_account(1, "acc1") -> true
deposit(2, "acc1", 1000) -> 1000
pay(3, "acc1", 500) -> "payment1"
create_account(4, "acc2") -> true
merge_accounts(5, "acc2", "acc1") -> true
get_balance(6, "acc1", 5) -> null
get_payment_status(6, "acc1", "payment1") -> null
get_balance(6, "acc2", 1) -> 0
get_balance(6, "acc2", 3) -> 500
get_balance(6, "acc2", 5) -> 500
merge_accounts(7, "acc2", "acc2") -> false
```

acc1 is gone. Time 3 is still acc1's 500, because acc2 did not exist yet.
Time 4 is acc2's create row, 0 (moved history is concatenated, last row
at that time wins). Time 5 is the merged snapshot, 500. `top_spenders`
with room for two ids lists only acc2.

```
get_balance(1, "missing", 1) -> null
create_account(2, "acc1") -> true
get_balance(3, "acc1", 1) -> null
```

A missing account is null. A `time_at` before the account exists is
also null.

```
create_account(1, "acc1") -> true
deposit(2, "acc1", 1000) -> 1000
create_account(3, "acc2") -> true
deposit(4, "acc2", 200) -> 200
deposit(5, "acc1", 50) -> 1050
merge_accounts(6, "acc1", "acc2") -> true
get_balance(7, "acc1", 3) -> 0
get_balance(7, "acc1", 4) -> 200
get_balance(7, "acc1", 5) -> 1050
get_balance(7, "acc1", 6) -> 1250
```

Keep still had a deposit after drop's last row. History is both lists
plus the merge snapshot. Time 3 and 4 are drop's create and deposit.
