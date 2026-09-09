# Rate limiter level 1

`allow(key, timestamp)` spends one token for `key` in the current
window. Default is 3 tokens per 10 time units. Windows are aligned:
the window id is `timestamp // 10`. Returns `"true"` if the token
fits, `"false"` if the window is full. Keys are independent.

## Example

```
allow("api", 0) -> "true"
allow("api", 1) -> "true"
allow("api", 2) -> "true"
allow("api", 3) -> "false"
allow("other", 3) -> "true"
allow("api", 10) -> "true"
allow("late", 8) -> "true"
allow("late", 9) -> "true"
allow("late", 10) -> "true"
allow("late", 11) -> "true"
allow("late", 12) -> "true"
allow("late", 13) -> "false"
```
