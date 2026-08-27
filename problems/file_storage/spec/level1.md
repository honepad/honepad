# File storage level 1

Shared cloud files.

- `add_file(name, size)` returns `"true"` if created, `"false"` if the name exists. Done by admin with unlimited capacity.
- `get_file_size(name)` returns the size as a string, or `""`.
- `delete_file(name)` returns the deleted size as a string, or `""`.
- `copy_file(source, dest)` copies size from source to dest. Returns the dest size as a string. Missing source returns `""`. Dest is overwritten if it exists. Same name returns the size and changes nothing. A new dest belongs to the source owner. An existing dest keeps its owner. Fail with `""` if that owner has a capacity limit and the size change would exceed it.

