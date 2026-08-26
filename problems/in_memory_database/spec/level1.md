# In-memory database level 1

Records are `key -> field -> value` (all strings).

- `set(key, field, value)` returns `""`.
- `get(key, field)` returns the value or `""`.
- `delete(key, field)` returns `"true"` or `"false"`.
