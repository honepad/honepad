"""Reference topic inbox."""

from __future__ import annotations


class Simulation:
    def __init__(self) -> None:
        self.subs: dict[str, list[str]] = {}
        self.inbox_map: dict[str, list[str]] = {}
        self.retained: dict[str, str] = {}

    def subscribe(self, topic: str, client: str) -> str:
        clients = self.subs.setdefault(topic, [])
        if client in clients:
            return "false"
        clients.append(client)
        if topic in self.retained:
            self.inbox_map.setdefault(client, []).append(f"{topic}:{self.retained[topic]}")
        return "true"

    def unsubscribe(self, topic: str, client: str) -> str:
        clients = self.subs.get(topic)
        if clients is None or client not in clients:
            return "false"
        clients.remove(client)
        if not clients:
            del self.subs[topic]
        return "true"

    def publish(self, topic: str, message: str) -> str:
        clients = self.subs.get(topic, [])
        payload = f"{topic}:{message}"
        for client in clients:
            self.inbox_map.setdefault(client, []).append(payload)
        return str(len(clients))

    def inbox(self, client: str) -> str:
        return ", ".join(self.inbox_map.get(client, []))

    def list_topics(self) -> str:
        return ", ".join(sorted(self.subs))

    def subscribers(self, topic: str) -> str:
        return ", ".join(sorted(self.subs.get(topic, [])))

    def peek(self, client: str) -> str:
        items = self.inbox_map.get(client, [])
        return items[0] if items else ""

    def ack(self, client: str, n: int) -> str:
        if n <= 0 or client not in self.inbox_map:
            return "invalid_request"
        items = self.inbox_map[client]
        if n > len(items):
            return "invalid_request"
        del items[:n]
        return str(len(items))

    def retain(self, topic: str, message: str) -> str:
        self.retained[topic] = message
        return ""
