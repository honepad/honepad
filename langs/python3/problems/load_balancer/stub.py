class Simulation:
    def __init__(self):
        pass

    def add_backend(self, backend_id):
        """Register a backend. "true" if created, "false" if it exists."""
        raise NotImplementedError

    def route(self):
        """Next backend id, or ""."""
        raise NotImplementedError

    def set_health(self, backend_id, flag):
        """1 up, 0 down. "true" or "invalid_request"."""
        raise NotImplementedError

    def set_weight(self, backend_id, weight):
        """Turns per cycle. "true" or "invalid_request"."""
        raise NotImplementedError

    def sticky(self, client_id):
        """Same healthy backend for this client, or ""."""
        raise NotImplementedError

    def done(self, backend_id):
        """Drop one in-flight. "true" or "invalid_request"."""
        raise NotImplementedError
