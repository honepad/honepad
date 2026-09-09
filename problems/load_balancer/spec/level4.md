# Load balancer level 4

`route` and `sticky` increment in-flight on the chosen backend.
`done(backend_id)` decrements it. Returns `"true"`. Unknown id or
in-flight already 0 is `"invalid_request"`.

After the first successful `done`, pick the healthy backend with
the least in-flight count. Ties keep the weighted robin order.

## Example

```
add_backend("a") -> "true"
add_backend("b") -> "true"
route() -> "a"
route() -> "b"
done("a") -> "true"
route() -> "a"
done("z") -> "invalid_request"
done("a") -> "true"
done("a") -> "invalid_request"
```
