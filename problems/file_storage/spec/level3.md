# File storage level 3

- `add_user(user_id, capacity)` returns `"true"` or `"false"`.
- `add_file_by(user_id, name, size)` returns remaining capacity as a string, or `""` if the user is missing, the name exists, or the file would exceed capacity.
- `add_file` is admin with unlimited capacity.
- `merge_user(keep, drop)` moves drop's files onto keep and adds drop's capacity to keep's limit, then deletes drop. Returns keep's remaining capacity, or `""` if a user is missing or the ids match.
