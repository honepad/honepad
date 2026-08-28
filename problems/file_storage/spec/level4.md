# File storage level 4

`backup_user(user_id)` stores that user's current files. A later
backup replaces the last one. Returns the file count as a string.
Missing user returns `""`.

`restore_user(user_id)` deletes the user's live files, then restores
the latest backup. A name now owned by another user is skipped.
No backup means delete the live files and return `"0"`. Missing user
returns `""`.

`merge_user` also deletes the dropped user's backup.

## Example

```
add_user("user", 100) -> "true"
add_file_by("user", "/a.txt", 10) -> "90"
add_file_by("user", "/b.txt", 20) -> "70"
backup_user("user") -> "2"
delete_file("/a.txt") -> "10"
add_file_by("user", "/c.txt", 5) -> "75"
restore_user("user") -> "2"
```

After restore, `/a.txt` is 10 and `/b.txt` is 20. `/c.txt` is gone.

```
add_user("user", 100) -> "true"
add_file_by("user", "/dir/file1", 50) -> "50"
add_file_by("user", "/file2.txt", 30) -> "20"
restore_user("user") -> "0"
```

There was no backup. Live files are deleted. The return is `"0"`.

```
add_user("alice", 100) -> "true"
add_user("bob", 100) -> "true"
add_file_by("alice", "/shared.txt", 10) -> "90"
backup_user("alice") -> "1"
delete_file("/shared.txt") -> "10"
add_file_by("bob", "/shared.txt", 15) -> "85"
restore_user("alice") -> "0"
```

bob now owns `/shared.txt`, so alice's copy is skipped. The restore
count is `"0"`. The live file stays bob's size 15.

```
backup_user("ghost") -> ""
restore_user("ghost") -> ""
```
