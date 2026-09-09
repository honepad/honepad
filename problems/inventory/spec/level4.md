# Inventory level 4

`ship(sku, n)` consumes `n` reserved units. On-hand and reserved both
drop by `n`. Returns `"true"` if `n > 0` and at least `n` are reserved.
Otherwise `"invalid_request"`.

## Example

```
create_item("sku-a", "Bolt") -> "true"
stock("sku-a", 10) -> "10"
reserve("sku-a", 4) -> "true"
ship("sku-a", 4) -> "true"
get_qty("sku-a") -> "6"
ship("sku-a", 1) -> "invalid_request"
reserve("sku-a", 2) -> "true"
ship("sku-a", 2) -> "true"
get_qty("sku-a") -> "4"
```
