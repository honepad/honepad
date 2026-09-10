"""Inventory public-practice problem."""

import importlib.util

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def _inv_solution_class():
    path = repo_root() / "langs" / "python3" / "problems" / "inventory" / "solution.py"
    spec = importlib.util.spec_from_file_location("honepad_inv_solution", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.Simulation


def _replay_inv_cases(cls, level: int) -> list[str]:
    failed: list[str] = []
    for case in load_cases("inventory", level):
        sim = cls()
        for row in case["calls"]:
            got = getattr(sim, row["m"])(*row["a"])
            if got != row["e"]:
                failed.append(f"{case['id']} {row['m']} {row['a']}: {got!r} != {row['e']!r}")
                break
    return failed


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


def test_inventory_ship_must_require_reserved() -> None:
    official = _inv_solution_class()

    class Naive(official):
        def ship(self, sku: str, n: int) -> str:
            item = self.items.get(sku)
            if item is None or n <= 0 or n > item.qty:
                return "invalid_request"
            item.qty -= n
            return "true"

    failed = _replay_inv_cases(Naive, 4)
    assert failed
    assert any(row.startswith("inv-l4-spec") for row in failed)


def test_inventory_l4_spec_ships_unreserved() -> None:
    cases = load_cases("inventory", 4)
    spec = next(case for case in cases if case["id"] == "inv-l4-spec")
    assert {"m": "ship", "a": ["sku-a", 1], "e": "invalid_request"} in spec["calls"]
