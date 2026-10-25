# Text editor level 3

`undo()` reverts the latest mutating op (`insert`, `erase`,
`type_text`) and restores the cursor to the pre-op position. Returns
`"true"` if an op was reverted, `"false"` if nothing to undo.

`redo()` reapplies an undone op. Returns `"true"` if one was
reapplied, `"false"` if nothing to redo. A new `insert`, `erase`, or
`type_text` clears the redo stack. Level 4 `cut()` and `paste()`
change the buffer and are not in this set. They do not clear the
redo stack.

## Example

```
insert(0, "hello") -> "5"
erase(1, 3) -> "ell"
get_text() -> "ho"
undo() -> "true"
get_text() -> "hello"
cursor() -> "0"
type_text("X") -> "6"
get_text() -> "Xhello"
undo() -> "true"
get_text() -> "hello"
cursor() -> "0"
redo() -> "true"
get_text() -> "Xhello"
cursor() -> "1"
insert(6, "!") -> "7"
redo() -> "false"
get_text() -> "Xhello!"
```

`type_text` moved the cursor to 1. Undo puts it back at 0, and redo
returns it to 1.
