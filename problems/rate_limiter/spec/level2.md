# Rate limiter level 2

`configure(key, limit, window)` sets that key's token count and
window length. Returns `"true"`. `limit <= 0` or `window <= 0` is
`"invalid_request"`. Configure resets that key's used count.
Unknown keys keep the default of 3 tokens per 10.

## Example

```
configure("api", 2, 10) -> "true"
allow("api", 0) -> "true"
allow("api", 1) -> "true"
allow("api", 2) -> "false"
configure("api", 0, 10) -> "invalid_request"
configure("api", 2, 0) -> "invalid_request"
allow("fresh", 0) -> "true"
allow("fresh", 1) -> "true"
allow("fresh", 2) -> "true"
allow("fresh", 3) -> "false"
configure("api", 1, 5) -> "true"
allow("api", 0) -> "true"
allow("api", 4) -> "false"
allow("api", 5) -> "true"
```
