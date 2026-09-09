# Inventory level 2

`list_low(threshold)` returns skus whose on-hand quantity is at most
`threshold`, as `id(qty)` pairs sorted by quantity then sku. Empty is
`""`.

## Example

```
create_item("sku-a", "Bolt") -> "true"
create_item("sku-b", "Nut") -> "true"
create_item("sku-c", "Washer") -> "true"
create_item("sku-d", "Screw") -> "true"
stock("sku-a", 5) -> "5"
stock("sku-b", 2) -> "2"
stock("sku-c", 8) -> "8"
stock("sku-d", 2) -> "2"
list_low(5) -> "sku-b(2), sku-d(2), sku-a(5)"
list_low(1) -> ""
```
