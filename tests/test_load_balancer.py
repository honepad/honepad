"""Load balancer public-practice problem."""

from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def test_load_balancer_max_level_is_4() -> None:
    assert max_level("load_balancer") == 4
    assert "add_backend" in methods_through_level("load_balancer", 1, "snake")
    assert "set_health" in methods_through_level("load_balancer", 2, "snake")
    assert "set_health" not in methods_through_level("load_balancer", 1, "snake")
    assert "done" in methods_through_level("load_balancer", 4, "snake")
    assert "done" not in methods_through_level("load_balancer", 3, "snake")


def test_load_balancer_python_solution() -> None:
    from honepad.runner import run_python

    report = run_python("load_balancer", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("load_balancer", 4))


def test_load_balancer_l1_work_hides_later_methods(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "load_balancer", "python3", "--no-console"]) == 0
    work = tmp_path / "work" / "load_balancer" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def add_backend" in text
    assert "def set_health" not in text
    assert "def done" not in text
