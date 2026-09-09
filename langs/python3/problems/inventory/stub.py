class Simulation:
    def __init__(self):
        pass

    def create_item(self, sku, name):
        """Returns "true" if created, "false" if the sku exists."""
        raise NotImplementedError

    def stock(self, sku, delta):
        """Add delta units. New qty as a string, "" if missing, or invalid_request."""
        raise NotImplementedError

    def get_qty(self, sku):
        """On-hand quantity as a string, or ""."""
        raise NotImplementedError

    def list_low(self, threshold):
        """Skus at or below threshold as id(qty), or ""."""
        raise NotImplementedError

    def reserve(self, sku, n):
        """Hold n on-hand units. "true" or "invalid_request"."""
        raise NotImplementedError

    def release(self, sku, n):
        """Free n reserved units. "true" or "invalid_request"."""
        raise NotImplementedError

    def ship(self, sku, n):
        """Consume n reserved units. "true" or "invalid_request"."""
        raise NotImplementedError
