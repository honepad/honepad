class InMemoryDatabase:
    def __init__(self):
        pass

    def set(self, key, field, value):
        raise NotImplementedError

    def get(self, key, field):
        raise NotImplementedError

    def delete(self, key, field):
        raise NotImplementedError

    def scan(self, key):
        raise NotImplementedError

    def scan_by_prefix(self, key, prefix):
        raise NotImplementedError

    def set_at(self, key, field, value, timestamp):
        raise NotImplementedError

    def set_at_with_ttl(self, key, field, value, timestamp, ttl):
        raise NotImplementedError

    def delete_at(self, key, field, timestamp):
        raise NotImplementedError

    def get_at(self, key, field, timestamp):
        raise NotImplementedError

    def scan_at(self, key, timestamp):
        raise NotImplementedError

    def scan_by_prefix_at(self, key, prefix, timestamp):
        raise NotImplementedError

    def backup(self, timestamp):
        raise NotImplementedError

    def restore(self, timestamp, timestamp_to_restore):
        raise NotImplementedError
