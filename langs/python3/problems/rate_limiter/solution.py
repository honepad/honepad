"""Reference rate limiter."""

from __future__ import annotations


class KeyState:
    def __init__(self) -> None:
        self.limit = 3
        self.window = 10
        self.window_id: int | None = None
        self.used = 0


class Simulation:
    def __init__(self) -> None:
        self.keys: dict[str, KeyState] = {}

    def _state(self, key: str) -> KeyState:
        item = self.keys.get(key)
        if item is None:
            item = KeyState()
            self.keys[key] = item
        return item

    def _used_at(self, item: KeyState, timestamp: int, persist: bool) -> int:
        window_id = timestamp // item.window
        if item.window_id is None or window_id != item.window_id:
            if persist:
                item.window_id = window_id
                item.used = 0
            return 0
        return item.used

    def allow(self, key: str, timestamp: int) -> str:
        return self.allow_weighted(key, 1, timestamp)

    def configure(self, key: str, limit: int, window: int) -> str:
        if limit <= 0 or window <= 0:
            return "invalid_request"
        item = self._state(key)
        item.limit = limit
        item.window = window
        item.window_id = None
        item.used = 0
        return "true"

    def remaining(self, key: str, timestamp: int) -> str:
        item = self._state(key)
        used = self._used_at(item, timestamp, persist=False)
        return str(item.limit - used)

    def allow_weighted(self, key: str, cost: int, timestamp: int) -> str:
        if cost <= 0:
            return "invalid_request"
        item = self._state(key)
        self._used_at(item, timestamp, persist=True)
        if item.used + cost > item.limit:
            return "false"
        item.used += cost
        return "true"
