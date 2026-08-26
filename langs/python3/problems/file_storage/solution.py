"""Reference cloud file storage. Traces follow the public LibreSignal storage specs."""

from __future__ import annotations


class StoredFile:
    def __init__(self, name: str, size: int, owner: str) -> None:
        self.name = name
        self.size = size
        self.owner = owner


class Simulation:
    def __init__(self) -> None:
        self.files: dict[str, StoredFile] = {}
        self.capacity: dict[str, int | None] = {"admin": None}
        self.backups: dict[str, dict[str, int]] = {}

    def _used(self, user_id: str) -> int:
        return sum(item.size for item in self.files.values() if item.owner == user_id)

    def _remaining(self, user_id: str) -> int | None:
        cap = self.capacity.get(user_id)
        if cap is None:
            return None
        return cap - self._used(user_id)

    def add_file(self, name: str, size: int) -> str:
        if name in self.files:
            return "false"
        self.files[name] = StoredFile(name, size, "admin")
        return "true"

    def get_file_size(self, name: str) -> str:
        item = self.files.get(name)
        return "" if item is None else str(item.size)

    def delete_file(self, name: str) -> str:
        item = self.files.pop(name, None)
        return "" if item is None else str(item.size)

    def get_n_largest(self, prefix: str, n: int) -> str:
        matched = [item for item in self.files.values() if item.name.startswith(prefix)]
        matched.sort(key=lambda item: (-item.size, item.name))
        top = matched[:n]
        return ", ".join(f"{item.name}({item.size})" for item in top)

    def add_user(self, user_id: str, capacity: int) -> str:
        if user_id in self.capacity:
            return "false"
        self.capacity[user_id] = capacity
        return "true"

    def add_file_by(self, user_id: str, name: str, size: int) -> str:
        if user_id not in self.capacity or name in self.files:
            return ""
        remaining = self._remaining(user_id)
        if remaining is not None and size > remaining:
            return ""
        self.files[name] = StoredFile(name, size, user_id)
        left = self._remaining(user_id)
        return "" if left is None else str(left)

    def merge_user(self, user_id1: str, user_id2: str) -> str:
        if user_id1 == user_id2:
            return ""
        if user_id1 not in self.capacity or user_id2 not in self.capacity:
            return ""
        cap1 = self.capacity[user_id1]
        cap2 = self.capacity[user_id2]
        if cap1 is None or cap2 is None:
            return ""
        self.capacity[user_id1] = cap1 + cap2
        for item in self.files.values():
            if item.owner == user_id2:
                item.owner = user_id1
        self.capacity.pop(user_id2, None)
        self.backups.pop(user_id2, None)
        left = self._remaining(user_id1)
        return "" if left is None else str(left)

    def backup_user(self, user_id: str) -> str:
        if user_id not in self.capacity:
            return ""
        self.backups[user_id] = {
            item.name: item.size for item in self.files.values() if item.owner == user_id
        }
        return str(len(self.backups[user_id]))

    def restore_user(self, user_id: str) -> str:
        if user_id not in self.capacity:
            return ""
        for name in [name for name, item in self.files.items() if item.owner == user_id]:
            del self.files[name]
        snapshot = self.backups.get(user_id)
        if snapshot is None:
            return "0"
        restored = 0
        for name, size in snapshot.items():
            if name in self.files:
                continue
            remaining = self._remaining(user_id)
            if remaining is not None and size > remaining:
                continue
            self.files[name] = StoredFile(name, size, user_id)
            restored += 1
        return str(restored)
