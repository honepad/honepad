# Pubsub level 3

`peek(client)` returns the oldest inbox message, or `""`.

`ack(client, n)` drops the oldest `n` messages and returns the
remaining inbox count as a string. `n <= 0` or a missing client is
`"invalid_request"`. Dropping more than the inbox size is
`"invalid_request"` and the inbox stays.

## Example

```
subscribe("t", "c1") -> "true"
publish("t", "a") -> "1"
publish("t", "b") -> "1"
peek("c1") -> "t:a"
ack("c1", 1) -> "1"
peek("c1") -> "t:b"
ack("c1", 1) -> "0"
peek("c1") -> ""
ack("c1", 1) -> "invalid_request"
ack("c1", 0) -> "invalid_request"
ack("ghost", 1) -> "invalid_request"
publish("t", "c") -> "1"
publish("t", "d") -> "1"
ack("c1", 3) -> "invalid_request"
inbox("c1") -> "t:c, t:d"
ack("c1", 2) -> "0"
```
