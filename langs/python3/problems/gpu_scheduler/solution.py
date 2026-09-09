"""Reference GPU scheduler."""

from __future__ import annotations


class Gpu:
    def __init__(self, gpu_id: str, mem: int) -> None:
        self.gpu_id = gpu_id
        self.mem = mem
        self.job_id: str | None = None


class Job:
    def __init__(self, job_id: str, mem: int, seq: int) -> None:
        self.job_id = job_id
        self.mem = mem
        self.seq = seq
        self.priority = 0
        self.state = "queued"
        self.gpu_id: str | None = None


class Simulation:
    def __init__(self) -> None:
        self.gpus: dict[str, Gpu] = {}
        self.gpu_order: list[str] = []
        self.jobs: dict[str, Job] = {}
        self.next_seq = 0

    def add_gpu(self, gpu_id: str, mem: int) -> str:
        if mem <= 0:
            return "invalid_request"
        if gpu_id in self.gpus:
            return "false"
        self.gpus[gpu_id] = Gpu(gpu_id, mem)
        self.gpu_order.append(gpu_id)
        return "true"

    def submit_job(self, job_id: str, mem: int) -> str:
        if mem <= 0:
            return "invalid_request"
        if job_id in self.jobs:
            return "false"
        self.jobs[job_id] = Job(job_id, mem, self.next_seq)
        self.next_seq += 1
        return "true"

    def status(self, job_id: str) -> str:
        job = self.jobs.get(job_id)
        if job is None:
            return ""
        return job.state

    def _place(self, job: Job, gpu: Gpu) -> None:
        job.state = "running"
        job.gpu_id = gpu.gpu_id
        gpu.job_id = job.job_id

    def assign(self) -> str:
        queued = [job for job in self.jobs.values() if job.state == "queued"]
        queued.sort(key=lambda job: (-job.priority, job.seq))
        for job in queued:
            for gpu_id in self.gpu_order:
                gpu = self.gpus[gpu_id]
                if gpu.job_id is None and gpu.mem >= job.mem:
                    self._place(job, gpu)
                    return job.job_id
        return ""

    def complete(self, job_id: str) -> str:
        job = self.jobs.get(job_id)
        if job is None or job.state != "running" or job.gpu_id is None:
            return "invalid_request"
        self.gpus[job.gpu_id].job_id = None
        job.gpu_id = None
        job.state = "done"
        return "true"

    def cancel(self, job_id: str) -> str:
        job = self.jobs.get(job_id)
        if job is None or job.state in {"done"}:
            return "invalid_request"
        if job.state == "running" and job.gpu_id is not None:
            self.gpus[job.gpu_id].job_id = None
        del self.jobs[job_id]
        if job.state == "running":
            self.assign()
        return "true"

    def set_priority(self, job_id: str, priority: int) -> str:
        job = self.jobs.get(job_id)
        if job is None or job.state != "queued":
            return "invalid_request"
        job.priority = priority
        return "true"
