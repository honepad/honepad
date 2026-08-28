# In-memory database level 2

`scan(key)` lists every field on that key.

Each item is `field(value)`. Items are joined with `", "`. Sort by
field name, A to Z. A missing key, or a key with no fields, returns
`""`.

`scan_by_prefix(key, prefix)` is the same list, but only fields whose
names start with `prefix`.

## Example

```
set("user1", "name", "Alice") -> ""
set("user1", "age", "30") -> ""
set("user1", "city", "NY") -> ""
set("user1", "abc", "123") -> ""
scan("user1") -> "abc(123), age(30), city(NY), name(Alice)"
scan("non_existent") -> ""
scan_by_prefix("user1", "a") -> "abc(123), age(30)"
scan_by_prefix("user1", "n") -> "name(Alice)"
scan_by_prefix("user1", "xyz") -> ""
```

`abc` and `age` both start with `a`. `city` does not. `xyz` matches
no field, so the return is `""`.
