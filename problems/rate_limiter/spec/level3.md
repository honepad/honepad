# Rate limiter level 3

`remaining(key, timestamp)` returns unused tokens in the window that
contains `timestamp`, as a string. It does not spend a token. An
unknown key uses the default of 3 per 10. A later timestamp in a new
window reports a full bucket.

## Example

```
remaining("api", 0) -> "3"
allow("api", 0) -> "true"
remaining("api", 1) -> "2"
allow("api", 1) -> "true"
allow("api", 2) -> "true"
remaining("api", 3) -> "0"
remaining("api", 10) -> "3"
allow("api", 5) -> "false"
configure("slow", 5, 20) -> "true"
remaining("slow", 0) -> "5"
```
