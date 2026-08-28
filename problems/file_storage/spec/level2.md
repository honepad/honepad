# File storage level 2

`get_n_largest(prefix, n)` looks at files whose names start with
`prefix`.

It returns at most `n` files as one string: `name(size)`, then a comma
and a space, then the next file. Sort by size, high to low. If two
sizes match, sort those names A to Z. No matching file returns `""`.

## Example

```
add_file("/dir/file1.txt", 5) -> "true"
add_file("/dir/file2", 20) -> "true"
add_file("/dir/deeper/file3.mov", 9) -> "true"
get_n_largest("/dir", 2) -> "/dir/file2(20), /dir/deeper/file3.mov(9)"
get_n_largest("/dir/file", 3) -> "/dir/file2(20), /dir/file1.txt(5)"
get_n_largest("/another_dir", 3) -> ""
```

`/dir` matches all three. `n` is 2, so the size-5 file is dropped.
`/dir/file` matches only the two names that start with that prefix.
`/another_dir` matches nothing.

```
add_file("/big_file.mp4", 20) -> "true"
get_n_largest("/", 2) -> "/big_file.mp4(20), /dir/file2(20)"
```

Both files are size 20. The name `/big_file.mp4` sorts before
`/dir/file2`.
