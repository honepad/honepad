# In-memory database level 4

- `backup(timestamp)` snapshots non-expired records and returns the number of keys as a string. Store remaining TTL, not absolute expiry.
- `restore(timestamp, timestampToRestore)` loads the latest backup at or before `timestampToRestore` and restarts remaining TTLs from `timestamp`.
