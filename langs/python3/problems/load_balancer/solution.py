"""Reference load balancer."""

from __future__ import annotations


class Backend:
    def __init__(self, backend_id: str) -> None:
        self.backend_id = backend_id
        self.health = True
        self.weight = 1
        self.inflight = 0


class Simulation:
    def __init__(self) -> None:
        self.backends: list[Backend] = []
        self.by_id: dict[str, Backend] = {}
        self.cursor = 0
        self.sticky_map: dict[str, str] = {}
        self.use_least = False

    def add_backend(self, backend_id: str) -> str:
        if backend_id in self.by_id:
            return "false"
        item = Backend(backend_id)
        self.backends.append(item)
        self.by_id[backend_id] = item
        return "true"

    def set_health(self, backend_id: str, flag: int) -> str:
        item = self.by_id.get(backend_id)
        if item is None or flag not in (0, 1):
            return "invalid_request"
        item.health = flag == 1
        self._reset_cycle()
        return "true"

    def set_weight(self, backend_id: str, weight: int) -> str:
        item = self.by_id.get(backend_id)
        if item is None or weight <= 0:
            return "invalid_request"
        item.weight = weight
        self._reset_cycle()
        return "true"

    def _reset_cycle(self) -> None:
        self.cursor = 0
        self.use_least = False
        for item in self.backends:
            item.inflight = 0

    def _tickets(self, items: list[Backend]) -> list[Backend]:
        tickets: list[Backend] = []
        for item in items:
            tickets.extend([item] * item.weight)
        return tickets

    def _pick(self) -> Backend | None:
        healthy = [item for item in self.backends if item.health]
        if not healthy:
            return None
        pool = healthy
        if self.use_least:
            least = min(item.inflight for item in healthy)
            pool = [item for item in healthy if item.inflight == least]
        tickets = self._tickets(pool)
        if not tickets:
            return None
        chosen = tickets[self.cursor % len(tickets)]
        self.cursor += 1
        return chosen

    def _take(self) -> str:
        item = self._pick()
        if item is None:
            return ""
        item.inflight += 1
        return item.backend_id

    def route(self) -> str:
        return self._take()

    def sticky(self, client_id: str) -> str:
        bound = self.sticky_map.get(client_id)
        item = self.by_id.get(bound) if bound else None
        if item is not None and item.health:
            item.inflight += 1
            return item.backend_id
        chosen = self._take()
        if chosen:
            self.sticky_map[client_id] = chosen
        return chosen

    def done(self, backend_id: str) -> str:
        item = self.by_id.get(backend_id)
        if item is None or item.inflight <= 0:
            return "invalid_request"
        item.inflight -= 1
        self.use_least = True
        return "true"
