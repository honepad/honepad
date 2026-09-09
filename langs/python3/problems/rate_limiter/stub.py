class Simulation:
    def __init__(self):
        pass

    def allow(self, key, timestamp):
        """Spend one token. "true" if it fits, "false" if the window is full."""
        raise NotImplementedError

    def configure(self, key, limit, window):
        """Set that key's limit and window. "true" or "invalid_request"."""
        raise NotImplementedError

    def remaining(self, key, timestamp):
        """Unused tokens in this window as a string."""
        raise NotImplementedError

    def allow_weighted(self, key, cost, timestamp):
        """Spend cost tokens. "true", "false", or "invalid_request"."""
        raise NotImplementedError
