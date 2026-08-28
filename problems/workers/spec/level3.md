# Workers level 3

`promote(worker_id, new_position, new_compensation, start_timestamp)`
queues one pending change. It is applied on the next enter at or after
`start_timestamp`. Returns `"success"`. Missing worker, or a promo
already pending, returns `"invalid_request"`.

After the promo applies, `top_n_workers` uses the new position.
Finished time in the old position is not moved. A worker who has not
yet finished a session in the new position appears as `id(0)`.

`calc_salary(worker_id, start_timestamp, end_timestamp)` pays finished
sessions that overlap the window: overlap duration times the session
rate. Missing worker returns `""`. A window that overlaps no finished
time returns `"0"`.

## Example

```
add_worker("John", "Middle Developer", 200) -> "true"
register("John", 100) -> "registered"
register("John", 125) -> "registered"
promote("John", "Senior Developer", 500, 200) -> "success"
register("John", 150) -> "registered"
promote("John", "Senior Developer", 350, 250) -> "invalid_request"
register("John", 300) -> "registered"
register("John", 325) -> "registered"
calc_salary("John", 0, 500) -> "35000"
top_n_workers(3, "Senior Developer") -> "John(0)"
```

The first session is 25 at rate 200. The enter at 150 is before 200,
so the promo does not apply yet. The second session is 150 at rate
200. 25 * 200 + 150 * 200 is 35000. The exit at 300 is not an enter,
so Senior still has finished time 0.

```
register("John", 400) -> "registered"
get("John") -> "250"
top_n_workers(10, "Senior Developer") -> "John(75)"
top_n_workers(10, "Middle Developer") -> ""
calc_salary("John", 110, 350) -> "45500"
calc_salary("John", 900, 1400) -> "0"
```

The enter at 325 is at or after 200, so the promo applies. The next
session is 75 at rate 500. `get` is all finished time: 25 + 150 + 75.
Senior time is only that 75. Middle is empty because the current
position is Senior. The 110 to 350 window overlaps 15 + 150 + 25 of
those sessions (rates 200, 200, 500), which is 45500. 900 to 1400
overlaps nothing, so the return is `"0"`.
