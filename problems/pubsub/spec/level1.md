# Pubsub level 1

`subscribe(topic, client)` adds `client` to `topic`. Returns `"true"`
if the pair is new. Already subscribed is `"false"`.

`unsubscribe(topic, client)` removes that pair. Returns `"true"` if
removed. Not subscribed is `"false"`.

`publish(topic, message)` delivers `topic:message` to each subscriber
inbox in subscribe order. Returns the subscriber count as a string.
No subscribers is `"0"`.

`inbox(client)` returns delivered messages in order, joined with
`", "`. Empty is `""`.

## Example

```
subscribe("alerts", "c1") -> "true"
subscribe("alerts", "c1") -> "false"
subscribe("alerts", "c2") -> "true"
publish("alerts", "up") -> "2"
inbox("c1") -> "alerts:up"
inbox("c2") -> "alerts:up"
unsubscribe("alerts", "c1") -> "true"
unsubscribe("alerts", "c1") -> "false"
publish("alerts", "down") -> "1"
inbox("c1") -> "alerts:up"
inbox("c2") -> "alerts:up, alerts:down"
inbox("ghost") -> ""
publish("none", "x") -> "0"
```
