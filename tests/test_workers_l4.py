"""Workers L4 double-pay windows."""

from honepad.cli import main
from honepad.session import ensure_work_copy, max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def test_workers_max_level_is_4() -> None:
    assert max_level("workers") == 4
    assert len(load_cases("workers", 4)) > len(load_cases("workers", 3))
    assert "set_double_pay" in methods_through_level("workers", 4, "snake")
    assert "set_double_pay" not in methods_through_level("workers", 3, "snake")


def test_workers_l4_python_solution() -> None:
    from honepad.runner import run_python

    report = run_python("workers", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("workers", 4))


def test_workers_l1_work_hides_set_double_pay(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    work = tmp_path / "work" / "workers" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def add_worker" in text
    assert "def set_double_pay" not in text
    assert main(["start", "workers", "php", "--reset", "--no-console"]) == 0
    php = (tmp_path / "work" / "workers" / "php" / "work.php").read_text(encoding="utf-8")
    assert "set_double_pay" not in php
    assert "setDoublePay" not in php


def test_workers_l4_work_has_set_double_pay(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    work = ensure_work_copy("workers", "python3", reset=True, level=4)
    assert "def set_double_pay" in work.read_text(encoding="utf-8")
    php = ensure_work_copy("workers", "php", reset=True, level=4)
    assert "set_double_pay" in php.read_text(encoding="utf-8")
