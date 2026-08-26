"""Reference workers register. Traces follow the public LibreSignal workers specs."""

from __future__ import annotations


class Worker:
    def __init__(self, worker_id: str, position: str, compensation: int) -> None:
        self.worker_id = worker_id
        self.position = position
        self.compensation = compensation
        self.in_office = False
        self.entered_at: int | None = None
        self.finished: list[tuple[int, int, int, str]] = []
        self.pending_promo: tuple[str, int, int] | None = None

    def total_time(self) -> int:
        return sum(end - start for start, end, _rate, _pos in self.finished)

    def position_time(self, position: str) -> int:
        return sum(end - start for start, end, _rate, pos in self.finished if pos == position)

    def apply_promo_on_enter(self, timestamp: int) -> None:
        if self.pending_promo is None:
            return
        new_pos, new_comp, start_ts = self.pending_promo
        if timestamp >= start_ts:
            self.position = new_pos
            self.compensation = new_comp
            self.pending_promo = None


class Simulation:
    def __init__(self) -> None:
        self.workers: dict[str, Worker] = {}

    def add_worker(self, worker_id: str, position: str, compensation: int) -> str:
        if worker_id in self.workers:
            return "false"
        self.workers[worker_id] = Worker(worker_id, position, compensation)
        return "true"

    def register(self, worker_id: str, timestamp: int) -> str:
        worker = self.workers.get(worker_id)
        if worker is None:
            return "invalid_request"
        if worker.in_office:
            assert worker.entered_at is not None
            worker.finished.append(
                (worker.entered_at, timestamp, worker.compensation, worker.position)
            )
            worker.in_office = False
            worker.entered_at = None
            return "registered"
        worker.apply_promo_on_enter(timestamp)
        worker.in_office = True
        worker.entered_at = timestamp
        return "registered"

    def get(self, worker_id: str) -> str:
        worker = self.workers.get(worker_id)
        if worker is None:
            return ""
        return str(worker.total_time())

    def top_n_workers(self, n: int, position: str) -> str:
        matched = [w for w in self.workers.values() if w.position == position]
        matched.sort(key=lambda w: (-w.position_time(position), w.worker_id))
        return ", ".join(f"{w.worker_id}({w.position_time(position)})" for w in matched[:n])

    def promote(
        self,
        worker_id: str,
        new_position: str,
        new_compensation: int,
        start_timestamp: int,
    ) -> str:
        worker = self.workers.get(worker_id)
        if worker is None or worker.pending_promo is not None:
            return "invalid_request"
        worker.pending_promo = (new_position, new_compensation, start_timestamp)
        return "success"

    def calc_salary(self, worker_id: str, start_timestamp: int, end_timestamp: int) -> str:
        worker = self.workers.get(worker_id)
        if worker is None:
            return ""
        total = 0
        for session_start, session_end, rate, _pos in worker.finished:
            lo = max(session_start, start_timestamp)
            hi = min(session_end, end_timestamp)
            if hi > lo:
                total += (hi - lo) * rate
        return str(total)
