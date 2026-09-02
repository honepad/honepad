# Bank system level 3

`pay(timestamp, account_id, amount)` withdraws `amount` now.

It returns `"paymentN"`. `N` is a global counter that starts at 1 and
goes up on every successful pay. Missing account or not enough funds
returns null.

Status starts as `IN_PROGRESS`. Cashback is 2 percent of the payment,
integer divide (`amount * 2 / 100`). It is due 24 hours later
(`86400000` milliseconds after the pay timestamp). Apply every cashback
that is due at the start of each later call.

`get_payment_status(timestamp, account_id, payment)` returns
`IN_PROGRESS` or `CASHBACK_RECEIVED`. Wrong account or unknown payment
returns null.

A successful pay counts as outgoing for `top_spenders`. Incoming
transfers still do not.

## Example

```
create_account(1, "acc1") -> true
deposit(2, "acc1", 1000) -> 1000
pay(3, "acc1", 500) -> "payment1"
pay(4, "acc1", 300) -> "payment2"
create_account(5, "acc2") -> true
deposit(6, "acc2", 800) -> 800
transfer(7, "acc2", "acc1", 200) -> 600
top_spenders(8, 2) -> ["acc1(800)", "acc2(200)"]
```

acc1 outgoing is 500 + 300. acc2 outgoing is the 200 transfer. The
incoming 200 on acc1 does not count.

```
get_payment_status(4, "acc1", "payment1") -> "IN_PROGRESS"
get_payment_status(86400003, "acc1", "payment1") -> "CASHBACK_RECEIVED"
deposit(100800000, "acc1", 0) -> 510
```

Pay at 3 for 500 leaves balance 500. Cashback 10 is due at 86400003.
The later deposit of 0 applies that 10, so the new balance is 510.

```
pay(1, "non_existent", 100) -> null
```

A pay larger than the balance also returns null. A failed pay does not
use a payment id.

```
deposit(2, "acc1", 100) -> 100
pay(3, "acc1", 200) -> null
pay(4, "acc1", 100) -> "payment1"
```

The successful pay is still `payment1`.

```
deposit(2, "acc1", 200) -> 200
pay(3, "acc1", 49) -> "payment1"
deposit(86400004, "acc1", 0) -> 151
pay(86400005, "acc1", 50) -> "payment2"
deposit(172800006, "acc1", 0) -> 102
```

`49 * 2 / 100` is 0. `50 * 2 / 100` is 1.

```
pay(3, "acc1", 500) -> "payment1"
create_account(86400003, "acc2") -> true
get_payment_status(4, "acc1", "payment1") -> "CASHBACK_RECEIVED"
deposit(5, "acc1", 0) -> 510
```

`create_account` is a later call, so due cashbacks apply first. The
status and balance stay applied even if a later query uses an earlier
timestamp.
