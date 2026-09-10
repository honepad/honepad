# Pubsub level 4

`retain(topic, message)` stores the last retained message for
`topic`. Returns `""`. It does not deliver to current subscribers and
does not change publish counts.

A later `subscribe` on that topic immediately delivers
`topic:message` to the new client. That delivery is an inbox message.

## Example

```
retain("news", "hello") -> ""
subscribe("news", "c1") -> "true"
inbox("c1") -> "news:hello"
publish("news", "live") -> "1"
inbox("c1") -> "news:hello, news:live"
retain("news", "later") -> ""
inbox("c1") -> "news:hello, news:live"
subscribe("news", "c2") -> "true"
inbox("c2") -> "news:later"
```
