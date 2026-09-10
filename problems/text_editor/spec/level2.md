# Text editor level 2

The cursor starts at 0.

`move(pos)` sets the cursor and returns `"true"`. `pos < 0` or
`pos >` length is `"invalid_request"`.

`type_text(text)` inserts `text` at the cursor, advances the cursor
by `len(text)`, and returns the new length.

`cursor()` returns the current position as a string.

## Example

```
insert(0, "hi") -> "2"
cursor() -> "0"
move(2) -> "true"
type_text("!") -> "3"
get_text() -> "hi!"
cursor() -> "3"
move(0) -> "true"
type_text("say ") -> "7"
get_text() -> "say hi!"
cursor() -> "4"
move(-1) -> "invalid_request"
move(8) -> "invalid_request"
cursor() -> "4"
```
