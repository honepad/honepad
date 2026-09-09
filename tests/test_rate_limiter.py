"""Rate limiter public-practice problem."""

from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def test_rate_limiter_max_level_is_4() -> None:
    assert max_level("rate_limiter") == 4
    assert "allow" in methods_through_level("rate_limiter", 1, "snake")
    assert "configure" in methods_through_level("rate_limiter", 2, "snake")
    assert "configure" not in methods_through_level("rate_limiter", 1, "snake")
    assert "allow_weighted" in methods_through_level("rate_limiter", 4, "snake")
    assert "allow_weighted" not in methods_through_level("rate_limiter", 3, "snake")


def test_rate_limiter_python_solution() -> None:
    from honepad.runner import run_python

    report = run_python("rate_limiter", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("rate_limiter", 4))


def test_rate_limiter_l1_work_hides_later_methods(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "rate_limiter", "python3", "--no-console"]) == 0
    work = tmp_path / "work" / "rate_limiter" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def allow" in text
    assert "def configure" not in text
    assert "def remaining" not in text
    assert "def allow_weighted" not in text
