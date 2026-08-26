"""Reference in-memory database. Traces ported from public LibreSignal tests (MIT)."""

from __future__ import annotations

import bisect


class InMemoryDatabase:
    def __init__(self) -> None:
        self.database: dict[str, dict[str, tuple[str, int | None]]] = {}
        self.backup_timestamps: list[int] = []
        self.backup_states: list[dict[str, dict[str, tuple[str, int | None]]]] = []

    def _set_internal(self, key: str, field: str, value: str, expiry: int | None) -> str:
        self.database.setdefault(key, {})[field] = (value, expiry)
        return ""

    def _is_alive(self, key: str, field: str, timestamp: int) -> bool:
        if key not in self.database or field not in self.database[key]:
            return False
        _value, expiry = self.database[key][field]
        if expiry is None:
            return True
        return timestamp < expiry

    def set(self, key: str, field: str, value: str) -> str:
        return self._set_internal(key, field, value, None)

    def get(self, key: str, field: str) -> str:
        if key not in self.database or field not in self.database[key]:
            return ""
        return self.database[key][field][0]

    def delete(self, key: str, field: str) -> str:
        if key not in self.database or field not in self.database[key]:
            return "false"
        del self.database[key][field]
        return "true"

    def scan(self, key: str) -> str:
        if key not in self.database:
            return ""
        items = list(self.database[key].items())
        items.sort()
        return ", ".join(f"{field}({value[0]})" for field, value in items)

    def scan_by_prefix(self, key: str, prefix: str) -> str:
        if key not in self.database:
            return ""
        items = [
            (field, value)
            for field, value in self.database[key].items()
            if field.startswith(prefix)
        ]
        items.sort()
        return ", ".join(f"{field}({value[0]})" for field, value in items)

    def set_at(self, key: str, field: str, value: str, timestamp: int) -> str:
        del timestamp
        return self._set_internal(key, field, value, None)

    def set_at_with_ttl(
        self, key: str, field: str, value: str, timestamp: int, ttl: int
    ) -> str:
        return self._set_internal(key, field, value, timestamp + ttl)

    def delete_at(self, key: str, field: str, timestamp: int) -> str:
        if not self._is_alive(key, field, timestamp):
            return "false"
        del self.database[key][field]
        return "true"

    def get_at(self, key: str, field: str, timestamp: int) -> str:
        if not self._is_alive(key, field, timestamp):
            return ""
        return self.database[key][field][0]

    def scan_at(self, key: str, timestamp: int) -> str:
        if key not in self.database:
            return ""
        items = [
            (field, value[0])
            for field, value in self.database[key].items()
            if self._is_alive(key, field, timestamp)
        ]
        items.sort()
        return ", ".join(f"{field}({value})" for field, value in items)

    def scan_by_prefix_at(self, key: str, prefix: str, timestamp: int) -> str:
        if key not in self.database:
            return ""
        items = [
            (field, value[0])
            for field, value in self.database[key].items()
            if field.startswith(prefix) and self._is_alive(key, field, timestamp)
        ]
        items.sort()
        return ", ".join(f"{field}({value})" for field, value in items)

    def backup(self, timestamp: int) -> str:
        state: dict[str, dict[str, tuple[str, int | None]]] = {}
        for key, fields in self.database.items():
            for field, (value, expiry) in fields.items():
                if self._is_alive(key, field, timestamp):
                    remaining = None if expiry is None else expiry - timestamp
                    state.setdefault(key, {})[field] = (value, remaining)
        self.backup_timestamps.append(timestamp)
        self.backup_states.append(state)
        return str(len(state))

    def restore(self, timestamp: int, timestamp_to_restore: int) -> str:
        idx = bisect.bisect_right(self.backup_timestamps, timestamp_to_restore) - 1
        backup_state = self.backup_states[idx]
        self.database = {}
        for key, fields in backup_state.items():
            for field, (value, remaining) in fields.items():
                expiry = None if remaining is None else timestamp + remaining
                self._set_internal(key, field, value, expiry)
        return ""
