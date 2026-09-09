class Simulation:
    def __init__(self):
        pass

    def add_gpu(self, gpu_id, mem):
        """Register a device. "true", "false", or "invalid_request"."""
        raise NotImplementedError

    def submit_job(self, job_id, mem):
        """Queue a job. "true", "false", or "invalid_request"."""
        raise NotImplementedError

    def status(self, job_id):
        """queued, running, done, or ""."""
        raise NotImplementedError

    def assign(self):
        """Start one queued job. Job id or ""."""
        raise NotImplementedError

    def complete(self, job_id):
        """Finish a running job. "true" or "invalid_request"."""
        raise NotImplementedError

    def cancel(self, job_id):
        """Drop a queued or running job. "true" or "invalid_request"."""
        raise NotImplementedError

    def set_priority(self, job_id, priority):
        """Set a queued job's rank. "true" or "invalid_request"."""
        raise NotImplementedError
