# In-memory database level 2

- `scan(key)` returns `field(value)` pairs sorted by field, joined with `", "`, or `""`.
- `scan_by_prefix(key, prefix)` same, filtered by field prefix.
