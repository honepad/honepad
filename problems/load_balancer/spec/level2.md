# Load balancer level 2

`set_health(backend_id, flag)` marks a backend up (`1`) or down (`0`).
Returns `"true"`. Unknown id or a flag other than `0`/`1` is
`"invalid_request"`. `route` skips down backends.

`set_weight(backend_id, weight)` sets how many turns that backend
gets in a row. Default weight is 1. Returns `"true"`. Unknown id or
`weight <= 0` is `"invalid_request"`. `set_health` and `set_weight`
reset the robin cursor and in-flight counts.

## Example

```
add_backend("a") -> "true"
add_backend("b") -> "true"
set_health("b", 0) -> "true"
route() -> "a"
route() -> "a"
set_health("b", 1) -> "true"
set_weight("a", 2) -> "true"
route() -> "a"
route() -> "a"
route() -> "b"
set_health("z", 1) -> "invalid_request"
set_weight("a", 0) -> "invalid_request"
```
