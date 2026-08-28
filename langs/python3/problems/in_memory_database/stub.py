class InMemoryDatabase:
    def __init__(self):
        pass

    def set(self, key, field, value):
        """Write a field. Returns ""."""
        raise NotImplementedError

    def get(self, key, field):
        """Value, or "" if missing."""
        raise NotImplementedError

    def delete(self, key, field):
        """Returns "true" if deleted, "false" if missing."""
        raise NotImplementedError

    def scan(self, key):
        """Fields as field(value), ... sorted by field. Empty if none.

        Example: "abc(123), age(30), city(NY), name(Alice)".
        """
        raise NotImplementedError

    def scan_by_prefix(self, key, prefix):
        """Same as scan, only fields starting with prefix.

        Example: "abc(123), age(30)".
        """
        raise NotImplementedError

    def set_at(self, key, field, value, timestamp):
        """Write with no expiry. Returns ""."""
        raise NotImplementedError

    def set_at_with_ttl(self, key, field, value, timestamp, ttl):
        """Write live in [timestamp, timestamp + ttl). Returns ""."""
        raise NotImplementedError

    def delete_at(self, key, field, timestamp):
        """Delete if live at timestamp. "true" or "false"."""
        raise NotImplementedError

    def get_at(self, key, field, timestamp):
        """Value if live at timestamp, else ""."""
        raise NotImplementedError

    def scan_at(self, key, timestamp):
        """Live fields at timestamp as field(value), ..., or ""."""
        raise NotImplementedError

    def scan_by_prefix_at(self, key, prefix, timestamp):
        """Live fields with that prefix at timestamp, or ""."""
        raise NotImplementedError

    def backup(self, timestamp):
        """Snapshot live keys. Key count as a string."""
        raise NotImplementedError

    def restore(self, timestamp, timestamp_to_restore):
        """Load latest backup at or before timestamp_to_restore. Returns ""."""
        raise NotImplementedError
