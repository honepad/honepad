# Pubsub level 2

`list_topics()` returns topic ids that currently have at least one
subscriber, sorted, joined with `", "`. Empty is `""`.

`subscribers(topic)` returns client ids on that topic, sorted, joined
with `", "`. Empty is `""`.

## Example

```
subscribe("news", "bob") -> "true"
subscribe("alerts", "ann") -> "true"
subscribe("news", "ann") -> "true"
list_topics() -> "alerts, news"
subscribers("news") -> "ann, bob"
subscribers("alerts") -> "ann"
subscribers("none") -> ""
unsubscribe("alerts", "ann") -> "true"
list_topics() -> "news"
```
