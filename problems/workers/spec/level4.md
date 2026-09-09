# Workers level 4

`set_double_pay(worker_id, interval_begin, interval_end)` records a
half-open window `[interval_begin, interval_end)` as double-paid for
that worker. Returns `"true"` if recorded. Missing worker, or
`interval_end <= interval_begin`, returns `"invalid_request"`.

More than one window is allowed. Overlapping windows do not stack past
2x: a timestamp is either normal or double.

`calc_salary` still pays finished sessions that overlap the query
window. The overlap that sits in a double-pay window uses
`session_rate * 2`. The rest uses `session_rate`. Missing worker is
still `""`. A window that overlaps no finished time is still `"0"`.

`get` and `top_n_workers` stay time, not pay.

## Example

```
add_worker("John", "Middle Developer", 200) -> "true"
register("John", 100) -> "registered"
register("John", 200) -> "registered"
set_double_pay("John", 150, 180) -> "true"
calc_salary("John", 100, 200) -> "26000"
get("John") -> "100"
set_double_pay("Walter", 0, 10) -> "invalid_request"
set_double_pay("John", 180, 180) -> "invalid_request"
```

John finished 100 time at rate 200. Bonus `[150, 180)` is 30 units at
400. The other 70 units stay at 200. `70 * 200 + 30 * 400` is 26000.
`get` is still 100.

```
set_double_pay("John", 160, 200) -> "true"
calc_salary("John", 100, 200) -> "30000"
```

The two bonus windows cover `[150, 200)` once. 50 units at 400 plus 50
at 200 is 30000, not a 4x stack on `[160, 180)`.
