# In-memory database level 4

`backup(timestamp)` snapshots records that are still live at that
time. Store remaining TTL, not the original expiry instant. Returns
the number of keys as a string. Expired records are not stored, so a
fully expired store returns `"0"`.

`restore(timestamp, timestampToRestore)` loads the latest backup at or
before `timestampToRestore`. Remaining TTLs restart from `timestamp`.
Returns `""`.

## Example

```
set_at_with_ttl("A", "B", "C", 1, 10) -> ""
backup(3) -> "1"
backup(12) -> "0"
```

`B` lives in `[1, 11)`. A backup at 12 has nothing left.

```
set_at_with_ttl("A", "B", "C", 1, 10) -> ""
backup(3) -> "1"
set_at("A", "D", "E", 4) -> ""
backup(5) -> "1"
delete_at("A", "B", 8) -> "true"
backup(9) -> "1"
restore(10, 7) -> ""
set_at("B", "C", "D", 11) -> ""
scan_at("A", 15) -> "B(C), D(E)"
scan_at("A", 16) -> "D(E)"
scan_at("B", 17) -> "C(D)"
```

`restore(10, 7)` uses the backup taken at 5. At that backup, `B` still
had remaining TTL 6, so after restore it lives until 16. `D` had no
TTL. The delete at 8 is not in that backup. `scan_at("A", 16)` drops
`B` because 16 is past the restarted window.
