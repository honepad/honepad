class Simulation:
    def __init__(self):
        pass

    def add_worker(self, worker_id, position, compensation):
        raise NotImplementedError

    def register(self, worker_id, timestamp):
        raise NotImplementedError

    def get(self, worker_id):
        raise NotImplementedError

    def top_n_workers(self, n, position):
        raise NotImplementedError

    def promote(self, worker_id, new_position, new_compensation, start_timestamp):
        raise NotImplementedError

    def calc_salary(self, worker_id, start_timestamp, end_timestamp):
        raise NotImplementedError
