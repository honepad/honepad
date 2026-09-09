"""Inventory public-practice problem."""

from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def test_inventory_max_level_is_4() -> None:
    assert max_level("inventory") == 4
    assert "create_item" in methods_through_level("inventory", 1, "snake")
    assert "list_low" in methods_through_level("inventory", 2, "snake")
    assert "list_low" not in methods_through_level("inventory", 1, "snake")
    assert "ship" in methods_through_level("inventory", 4, "snake")
    assert "ship" not in methods_through_level("inventory", 3, "snake")


def test_inventory_python_solution() -> None:
    from honepad.runner import run_python

    report = run_python("inventory", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("inventory", 4))


def test_inventory_l1_work_hides_later_methods(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "inventory", "python3", "--no-console"]) == 0
    work = tmp_path / "work" / "inventory" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def create_item" in text
    assert "def list_low" not in text
    assert "def ship" not in text
