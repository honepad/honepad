# File storage level 1

Shared cloud files.

- `add_file(name, size)` returns `"true"` if created, `"false"` if the name exists. Done by admin with unlimited capacity.
- `get_file_size(name)` returns the size as a string, or `""`.
- `delete_file(name)` returns the deleted size as a string, or `""`.

