# File storage level 3

`add_user(user_id, capacity)` creates a user with that capacity.
Returns `"true"`. The same id again returns `"false"`.

`add_file_by(user_id, name, size)` stores the file as that user.
Returns remaining capacity as a string. Missing user, a name that
already exists, or a file that would exceed capacity returns `""`.

`add_file` is still the admin path. Admin has no capacity limit.

`merge_user(keep, drop)` moves drop's files onto keep and adds drop's
capacity to keep's limit, then deletes drop. Returns keep's remaining
capacity. Missing user or the same id twice returns `""`.

A copy onto a new name uses the source owner. If that owner is at
capacity, `copy_file` returns `""` and does not create the dest.

## Example

```
add_user("user1", 200) -> "true"
add_user("user1", 100) -> "false"
add_file_by("user1", "/dir/file.med", 50) -> "150"
add_file_by("user1", "/big.blob", 140) -> "10"
add_file_by("user1", "/file-small", 20) -> ""
add_file("/dir/admin_file", 300) -> "true"
add_user("user2", 110) -> "true"
add_file_by("user2", "/dir/file.med", 45) -> ""
add_file_by("user2", "/new_file", 50) -> "60"
merge_user("user1", "user2") -> "70"
```

user1 used 50 + 140. 20 more would pass 200, so that add is `""`.
The name `/dir/file.med` already exists, so user2 cannot take it.
After merge, keep's limit is 200 + 110. Files on keep are 50 + 140 +
50. Remaining is 70. The admin file is not on either user.

```
add_user("alice", 20) -> "true"
add_file_by("alice", "/x.txt", 10) -> "10"
copy_file("/x.txt", "/y.txt") -> "10"
copy_file("/x.txt", "/z.txt") -> ""
```

The first copy makes a new alice file and fills the 20 limit. The
second copy would exceed it, so dest is not created.
