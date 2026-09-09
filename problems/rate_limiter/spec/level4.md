# Rate limiter level 4

`allow_weighted(key, cost, timestamp)` spends `cost` tokens. Returns
`"true"` if they fit, `"false"` if `used + cost` would exceed the
limit (state unchanged). `cost <= 0` is `"invalid_request"`.
`allow` is cost 1.

## Example

```
configure("api", 5, 10) -> "true"
allow_weighted("api", 3, 0) -> "true"
remaining("api", 1) -> "2"
allow_weighted("api", 3, 1) -> "false"
allow_weighted("api", 2, 1) -> "true"
remaining("api", 2) -> "0"
allow_weighted("api", 0, 2) -> "invalid_request"
allow_weighted("api", -1, 2) -> "invalid_request"
allow("api", 10) -> "true"
remaining("api", 10) -> "4"
allow_weighted("api", 5, 10) -> "false"
allow_weighted("api", 4, 10) -> "true"
remaining("api", 11) -> "0"
```
