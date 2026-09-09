# Inventory level 1

`create_item(sku, name)` adds a sku with quantity 0. Returns `"true"` if
created. Duplicate sku returns `"false"`.

`stock(sku, delta)` adds `delta` (negative to remove). Returns the new
quantity as a string. Missing sku is `""`. A result below 0 is
`"invalid_request"` and the quantity stays.

`get_qty(sku)` returns the on-hand quantity as a string. Missing sku is
`""`.

## Example

```
create_item("sku-a", "Bolt") -> "true"
create_item("sku-a", "Bolt") -> "false"
stock("sku-a", 10) -> "10"
stock("sku-a", -3) -> "7"
get_qty("sku-a") -> "7"
get_qty("sku-z") -> ""
stock("sku-z", 1) -> ""
stock("sku-a", -8) -> "invalid_request"
get_qty("sku-a") -> "7"
```
