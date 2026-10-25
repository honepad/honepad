# Text editor level 4

`select(start, end)` marks the half-open span `[start, end)` and
returns `"true"`. Either bound out of range or `start > end` is
`"invalid_request"`. Select does not move the cursor.

`cut()` returns the selected substring, deletes it, and stores it on
the clipboard. The cursor moves to `start`, and the selection is
cleared. No selection or an empty selection is `"invalid_request"`.
`cut` is not undoable, and it does not clear the redo stack.

`copy_sel()` returns the selected substring and stores it on the
clipboard without deleting. It does not move the cursor or clear the
selection. No selection or an empty selection is `"invalid_request"`.

`paste()` inserts the clipboard at the cursor, advances the cursor by
the clipboard length, and returns the new length. It does not delete
a selection. An empty clipboard is `"invalid_request"`. `paste` is
not undoable, and it does not clear the redo stack.

Undo and redo still record only `insert`, `erase`, and `type_text`.
Those three clear the selection when they run. One `undo()` can jump
over `cut` and `paste` to the last recorded snapshot. The clipboard
stays. Undo and redo clear the selection.

## Example

```
insert(0, "hello world") -> "11"
select(6, 11) -> "true"
cursor() -> "0"
cut() -> "world"
cursor() -> "6"
get_text() -> "hello "
length() -> "6"
paste() -> "11"
cursor() -> "11"
get_text() -> "hello world"
select(0, 5) -> "true"
copy_sel() -> "hello"
move(11) -> "true"
paste() -> "16"
get_text() -> "hello worldhello"
```

The cursor is still 0 after `select`. `cut` moves it to 6, so
`paste` puts `world` back where it was removed. Paste then leaves
the cursor at 11.
