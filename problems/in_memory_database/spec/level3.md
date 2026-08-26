# In-memory database level 3

TTL is `[timestamp, timestamp+ttl)`.

- `set_at` / `set_at_with_ttl` / `get_at` / `delete_at` / `scan_at` / `scan_by_prefix_at`.
- `set` / `get` / `scan` / `scan_by_prefix` ignore expiry and see the last written value.
