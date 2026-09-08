# In-memory database level 4

`backup(timestamp)` snapshots records that are still live at that
time. Store remaining TTL, not the original expiry instant. Returns
the number of keys as a string. Expired records are not stored, so a
fully expired store returns `"0"`.

`restore(timestamp, timestampToRestore)` loads the latest backup at or
before `timestampToRestore`. Remaining TTLs restart from `timestamp`.
Copy the snapshot. Do not reuse the backup map or add `timestamp` onto
the stored remaining in place. Returns `""`.

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

```
set_at_with_ttl("A", "B", "C", 1, 10) -> ""
backup(3) -> "1"
restore(10, 3) -> ""
scan_at("A", 15) -> "B(C)"
set_at("A", "D", "E", 16) -> ""
restore(20, 3) -> ""
scan_at("A", 20) -> "B(C)"
scan_at("A", 28) -> ""
```

`backup(3)` stores remaining 8 for `B`. The second restore restarts
that 8 from 20, so `B` dies at 28. `D` was written after the first
restore and is not in the backup. A restore that points live state at
the backup map, or adds `timestamp` onto the stored remaining, keeps
`D` and expires `B` too late.
