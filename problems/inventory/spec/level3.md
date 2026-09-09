# Inventory level 3

`reserve(sku, n)` holds `n` on-hand units. Returns `"true"` if `n > 0`
and enough unreserved stock exists. Missing sku, `n <= 0`, or not
enough free units is `"invalid_request"`.

`release(sku, n)` frees `n` reserved units. Returns `"true"` if `n > 0`
and at least `n` are reserved. Otherwise `"invalid_request"`.

`stock` that would drop on-hand below the reserved count is
`"invalid_request"`. `get_qty` stays on-hand, not free.

## Example

```
create_item("sku-a", "Bolt") -> "true"
stock("sku-a", 10) -> "10"
reserve("sku-a", 4) -> "true"
stock("sku-a", -7) -> "invalid_request"
stock("sku-a", -6) -> "4"
get_qty("sku-a") -> "4"
release("sku-a", 2) -> "true"
reserve("sku-z", 1) -> "invalid_request"
reserve("sku-a", 0) -> "invalid_request"
```
