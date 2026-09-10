"""GPU scheduler public-practice problem."""

import importlib.util

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def _gpu_solution_class():
    path = repo_root() / "langs" / "python3" / "problems" / "gpu_scheduler" / "solution.py"
    spec = importlib.util.spec_from_file_location("honepad_gpu_solution", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.Simulation


def _replay_gpu_cases(cls, level: int) -> list[str]:
    failed: list[str] = []
    for case in load_cases("gpu_scheduler", level):
        sim = cls()
        for row in case["calls"]:
            got = getattr(sim, row["m"])(*row["a"])
            if got != row["e"]:
                failed.append(f"{case['id']} {row['m']} {row['a']}: {got!r} != {row['e']!r}")
                break
    return failed


def test_gpu_scheduler_max_level_is_4() -> None:
    assert max_level("gpu_scheduler") == 4
    assert "add_gpu" in methods_through_level("gpu_scheduler", 1, "snake")
    assert "assign" in methods_through_level("gpu_scheduler", 2, "snake")
    assert "assign" not in methods_through_level("gpu_scheduler", 1, "snake")
    assert "set_priority" in methods_through_level("gpu_scheduler", 4, "snake")
    assert "set_priority" not in methods_through_level("gpu_scheduler", 3, "snake")


def test_gpu_scheduler_python_solution() -> None:
    from honepad.runner import run_python

    report = run_python("gpu_scheduler", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("gpu_scheduler", 4))


def test_gpu_scheduler_l1_work_hides_later_methods(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "gpu_scheduler", "python3", "--no-console"]) == 0
    work = tmp_path / "work" / "gpu_scheduler" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def add_gpu" in text
    assert "def assign" not in text
    assert "def set_priority" not in text


def test_gpu_scheduler_assign_must_honor_priority() -> None:
    official = _gpu_solution_class()

    class Naive(official):
        def assign(self) -> str:
            queued = [job for job in self.jobs.values() if job.state == "queued"]
            queued.sort(key=lambda job: job.seq)
            for job in queued:
                for gpu_id in self.gpu_order:
                    gpu = self.gpus[gpu_id]
                    if gpu.job_id is None and gpu.mem >= job.mem:
                        self._place(job, gpu)
                        return job.job_id
            return ""

    failed = _replay_gpu_cases(Naive, 4)
    assert failed
    assert any(row.startswith("gpu-l4-spec") for row in failed)
