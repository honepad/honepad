# Load balancer level 1

`add_backend(backend_id)` registers a backend. Returns `"true"` if
created. Duplicate id is `"false"`.

`route()` returns the next backend in add order, then wraps. No
backends is `""`.

## Example

```
route() -> ""
add_backend("a") -> "true"
add_backend("b") -> "true"
add_backend("a") -> "false"
route() -> "a"
route() -> "b"
route() -> "a"
route() -> "b"
```
