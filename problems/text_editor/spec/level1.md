# Text editor level 1

`insert(pos, text)` inserts `text` at 0-based `pos`. Returns the new
length as a string. `pos < 0` or `pos >` length is
`"invalid_request"` and the buffer stays.

`erase(pos, n)` deletes `n` characters starting at `pos` and returns
the deleted substring. `n <= 0` or a range outside the buffer is
`"invalid_request"`.

`get_text()` returns the full buffer.

`length()` returns the length as a string.

## Example

```
insert(0, "hello") -> "5"
insert(5, " world") -> "11"
get_text() -> "hello world"
length() -> "11"
erase(5, 6) -> " world"
get_text() -> "hello"
erase(0, 0) -> "invalid_request"
erase(3, 10) -> "invalid_request"
insert(-1, "x") -> "invalid_request"
insert(6, "x") -> "invalid_request"
length() -> "5"
```
