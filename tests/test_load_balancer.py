"""Load balancer public-practice problem."""

import importlib.util

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def _lb_solution_class():
    path = repo_root() / "langs" / "python3" / "problems" / "load_balancer" / "solution.py"
    spec = importlib.util.spec_from_file_location("honepad_lb_solution", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.Simulation


def _replay_lb_cases(cls, level: int) -> list[str]:
    failed: list[str] = []
    for case in load_cases("load_balancer", level):
        sim = cls()
        for row in case["calls"]:
            got = getattr(sim, row["m"])(*row["a"])
            if got != row["e"]:
                failed.append(f"{case['id']} {row['m']} {row['a']}: {got!r} != {row['e']!r}")
                break
    return failed


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


def test_load_balancer_done_must_switch_to_least_conn() -> None:
    official = _lb_solution_class()

    class Naive(official):
        def done(self, backend_id: str) -> str:
            item = self.by_id.get(backend_id)
            if item is None or item.inflight <= 0:
                return "invalid_request"
            item.inflight -= 1
            return "true"

    failed = _replay_lb_cases(Naive, 4)
    assert failed
    assert any(row.startswith("lb-l4-spec") for row in failed)


def test_load_balancer_l4_spec_adds_three_backends() -> None:
    cases = load_cases("load_balancer", 4)
    spec = next(case for case in cases if case["id"] == "lb-l4-spec")
    added = [row["a"][0] for row in spec["calls"] if row["m"] == "add_backend"]
    assert added == ["a", "b", "c"]
