class Simulation:
    def __init__(self):
        pass

    def add_worker(self, worker_id, position, compensation):
        """Returns "true" if created, "false" if the id exists."""
        raise NotImplementedError

    def register(self, worker_id, timestamp):
        """Toggle in or out. "registered", or "invalid_request" if missing."""
        raise NotImplementedError

    def get(self, worker_id):
        """Total finished time as a string, or "" if missing."""
        raise NotImplementedError

    def top_n_workers(self, n, position):
        """Current position as id(time), ... Finished time in that position.

        Example: "Jason(50), John(50), Ashley(0)".
        """
        raise NotImplementedError

    def promote(self, worker_id, new_position, new_compensation, start_timestamp):
        """Queue one change. Applied on the next enter at or after start.

        Returns "success" or "invalid_request".
        """
        raise NotImplementedError

    def calc_salary(self, worker_id, start_timestamp, end_timestamp):
        """Pay for finished sessions overlapping the window, or ""."""
        raise NotImplementedError
