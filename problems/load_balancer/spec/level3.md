# Load balancer level 3

`sticky(client_id)` returns the same healthy backend for that client.
The first call for a client is a normal `route`. If the bound backend
is down, the client is rebound with `route`.

## Example

```
add_backend("a") -> "true"
add_backend("b") -> "true"
sticky("c1") -> "a"
sticky("c1") -> "a"
sticky("c2") -> "b"
set_health("a", 0) -> "true"
sticky("c1") -> "b"
```
