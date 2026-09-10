# Text editor level 4

`select(start, end)` marks the half-open span `[start, end)` and
returns `"true"`. Either bound out of range or `start > end` is
`"invalid_request"`.

`cut()` returns the selected substring, deletes it, and stores it on
the clipboard. No selection or an empty selection is
`"invalid_request"`.

`copy_sel()` returns the selected substring and stores it on the
clipboard without deleting. No selection or an empty selection is
`"invalid_request"`.

`paste()` inserts the clipboard at the cursor, advances the cursor,
and returns the new length. An empty clipboard is
`"invalid_request"`.

## Example

```
insert(0, "hello world") -> "11"
select(6, 11) -> "true"
cut() -> "world"
get_text() -> "hello "
length() -> "6"
paste() -> "11"
get_text() -> "hello world"
select(0, 5) -> "true"
copy_sel() -> "hello"
move(11) -> "true"
paste() -> "16"
get_text() -> "hello worldhello"
```
