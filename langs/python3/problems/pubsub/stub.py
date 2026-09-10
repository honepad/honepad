class Simulation:
    def __init__(self):
        pass

    def subscribe(self, topic, client):
        """Returns "true" if new, "false" if already subscribed."""
        raise NotImplementedError

    def unsubscribe(self, topic, client):
        """Returns "true" if removed, "false" if not subscribed."""
        raise NotImplementedError

    def publish(self, topic, message):
        """Deliver topic:message. Subscriber count, or "0"."""
        raise NotImplementedError

    def inbox(self, client):
        """Delivered messages as topic:message, or ""."""
        raise NotImplementedError

    def list_topics(self):
        """Sorted topics with subscribers, or ""."""
        raise NotImplementedError

    def subscribers(self, topic):
        """Sorted client ids on topic, or ""."""
        raise NotImplementedError

    def peek(self, client):
        """Oldest inbox message, or ""."""
        raise NotImplementedError

    def ack(self, client, n):
        """Drop oldest n. Remaining count, or invalid_request."""
        raise NotImplementedError

    def retain(self, topic, message):
        """Store last retained message. Returns ""."""
        raise NotImplementedError
