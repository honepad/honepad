# In-memory database level 3

TTL is the half-open window `[timestamp, timestamp + ttl)`.

At `timestamp + ttl` the field is gone.

`set_at(key, field, value, timestamp)` writes with no expiry.
`set_at_with_ttl(key, field, value, timestamp, ttl)` writes with that
window. A later write replaces the value and the expiry.

`get_at` / `delete_at` / `scan_at` / `scan_by_prefix_at` only see
fields that are still live at that timestamp.

`set` / `get` / `scan` / `scan_by_prefix` ignore expiry. They see the
last written value even after the TTL window ends.

Scan format is the same as level 2: `field(value)` items, comma-space,
sorted by field name.

## Example

```
set_at_with_ttl("user1", "name", "Alice", 100, 10) -> ""
get_at("user1", "name", 105) -> "Alice"
get_at("user1", "name", 110) -> ""
```

The window is `[100, 110)`. Time 110 is expired.

```
set_at_with_ttl("user1", "name", "Alice", 100, 10) -> ""
set_at_with_ttl("user1", "age", "30", 101, 5) -> ""
set_at_with_ttl("user1", "city", "NY", 102, 15) -> ""
scan_at("user1", 105) -> "age(30), city(NY), name(Alice)"
scan_at("user1", 106) -> "city(NY), name(Alice)"
scan_at("user1", 117) -> ""
scan("user1") -> "age(30), city(NY), name(Alice)"
```

`age` expires at 106. `name` expires at 110. `city` expires at 117.
`scan` without `_at` still returns every last write, including expired
fields.
