# Bank system level 2

`top_spenders(timestamp, n)` returns at most `n` strings.

Each string is `accountId(outgoing)`. `outgoing` is money that left
that account. A transfer out counts. A payment (level 3) also counts.
A deposit or an incoming transfer does not.

Sort by outgoing, high to low. If two accounts spent the same amount,
sort those ids A to Z. An account that spent 0 still appears if `n`
is large enough.

## Example

```
create_account(1, "acc1") -> true
create_account(2, "acc2") -> true
deposit(3, "acc1", 1000) -> 1000
transfer(4, "acc1", "acc2", 500) -> 500
top_spenders(5, 2) -> ["acc1(500)", "acc2(0)"]
```

acc1 sent 500, so its outgoing is 500. acc2 only received money, so
its outgoing is 0. `top_spenders(5, 1)` is `["acc1(500)"]`.

If acc1 and acc2 both spent 500 and acc3 spent 300:

```
top_spenders(10, 3) -> ["acc1(500)", "acc2(500)", "acc3(300)"]
```
