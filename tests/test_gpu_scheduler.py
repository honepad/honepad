"""GPU scheduler public-practice problem."""

from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


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
