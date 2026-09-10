"""Pubsub public-practice problem."""

import importlib.util

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def _ps_solution_class():
    path = repo_root() / "langs" / "python3" / "problems" / "pubsub" / "solution.py"
    spec = importlib.util.spec_from_file_location("honepad_ps_solution", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.Simulation


def _replay_ps_cases(cls, level: int) -> list[str]:
    failed: list[str] = []
    for case in load_cases("pubsub", level):
        sim = cls()
        for row in case["calls"]:
            got = getattr(sim, row["m"])(*row["a"])
            if got != row["e"]:
                failed.append(f"{case['id']} {row['m']} {row['a']}: {got!r} != {row['e']!r}")
                break
    return failed


def test_pubsub_max_level_is_4() -> None:
    assert max_level("pubsub") == 4
    assert "subscribe" in methods_through_level("pubsub", 1, "snake")
    assert "list_topics" in methods_through_level("pubsub", 2, "snake")
    assert "list_topics" not in methods_through_level("pubsub", 1, "snake")
    assert "retain" in methods_through_level("pubsub", 4, "snake")
    assert "retain" not in methods_through_level("pubsub", 3, "snake")


def test_pubsub_python_solution() -> None:
    from honepad.runner import run_python

    report = run_python("pubsub", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("pubsub", 4))


def test_pubsub_l1_work_hides_later_methods(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "pubsub", "python3", "--no-console"]) == 0
    work = tmp_path / "work" / "pubsub" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def subscribe" in text
    assert "def list_topics" not in text
    assert "def retain" not in text


def test_pubsub_retain_must_deliver_on_subscribe() -> None:
    official = _ps_solution_class()

    class Naive(official):
        def subscribe(self, topic: str, client: str) -> str:
            clients = self.subs.setdefault(topic, [])
            if client in clients:
                return "false"
            clients.append(client)
            return "true"

    failed = _replay_ps_cases(Naive, 4)
    assert failed
    assert any(row.startswith("ps-l4-spec") for row in failed)


def test_pubsub_l4_spec_delivers_retain() -> None:
    cases = load_cases("pubsub", 4)
    spec = next(case for case in cases if case["id"] == "ps-l4-spec")
    assert {"m": "retain", "a": ["news", "hello"], "e": ""} in spec["calls"]
    assert {"m": "inbox", "a": ["c1"], "e": "news:hello"} in spec["calls"]
