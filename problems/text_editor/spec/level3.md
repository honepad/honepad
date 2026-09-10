# Text editor level 3

`undo()` reverts the latest mutating op (`insert`, `erase`,
`type_text`) and restores the cursor to the pre-op position. Returns
`"true"` if an op was reverted, `"false"` if nothing to undo.

`redo()` reapplies an undone op. Returns `"true"` if one was
reapplied, `"false"` if nothing to redo. A new mutating op clears
the redo stack.

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
redo() -> "true"
get_text() -> "Xhello"
insert(6, "!") -> "7"
redo() -> "false"
get_text() -> "Xhello!"
```
