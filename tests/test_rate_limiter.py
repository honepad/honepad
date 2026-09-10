"""Rate limiter public-practice problem."""

import importlib.util

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def _rl_solution_class():
    path = repo_root() / "langs" / "python3" / "problems" / "rate_limiter" / "solution.py"
    spec = importlib.util.spec_from_file_location("honepad_rl_solution", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.Simulation


def _replay_rl_cases(cls, level: int) -> list[str]:
    failed: list[str] = []
    for case in load_cases("rate_limiter", level):
        sim = cls()
        for row in case["calls"]:
            got = getattr(sim, row["m"])(*row["a"])
            if got != row["e"]:
                failed.append(f"{case['id']} {row['m']} {row['a']}: {got!r} != {row['e']!r}")
                break
    return failed


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


def test_rate_limiter_allow_weighted_must_honor_cost() -> None:
    official = _rl_solution_class()

    class Naive(official):
        def allow_weighted(self, key: str, cost: int, timestamp: int) -> str:
            if cost <= 0:
                return "invalid_request"
            item = self._state(key)
            self._used_at(item, timestamp, persist=True)
            if item.used + 1 > item.limit:
                return "false"
            item.used += 1
            return "true"

    failed = _replay_rl_cases(Naive, 4)
    assert failed
    assert any(row.startswith("rl-l4-spec") for row in failed)
