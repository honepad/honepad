"""Text editor public-practice problem."""

import importlib.util

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.session import max_level
from honepad.traces import load_cases
from honepad.workstub import methods_through_level


def _te_solution_class():
    path = repo_root() / "langs" / "python3" / "problems" / "text_editor" / "solution.py"
    spec = importlib.util.spec_from_file_location("honepad_te_solution", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.Simulation


def _replay_te_cases(cls, level: int) -> list[str]:
    failed: list[str] = []
    for case in load_cases("text_editor", level):
        sim = cls()
        for row in case["calls"]:
            got = getattr(sim, row["m"])(*row["a"])
            if got != row["e"]:
                failed.append(f"{case['id']} {row['m']} {row['a']}: {got!r} != {row['e']!r}")
                break
    return failed


def test_text_editor_max_level_is_4() -> None:
    assert max_level("text_editor") == 4
    assert "insert" in methods_through_level("text_editor", 1, "snake")
    assert "type_text" in methods_through_level("text_editor", 2, "snake")
    assert "type_text" not in methods_through_level("text_editor", 1, "snake")
    assert "cut" in methods_through_level("text_editor", 4, "snake")
    assert "cut" not in methods_through_level("text_editor", 3, "snake")


def test_text_editor_python_solution() -> None:
    from honepad.runner import run_python

    report = run_python("text_editor", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("text_editor", 4))


def test_text_editor_l1_work_hides_later_methods(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "text_editor", "python3", "--no-console"]) == 0
    work = tmp_path / "work" / "text_editor" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def insert" in text
    assert "def type_text" not in text
    assert "def cut" not in text


def test_text_editor_cut_must_delete() -> None:
    official = _te_solution_class()

    class Naive(official):
        def cut(self) -> str:
            return self.copy_sel()

    failed = _replay_te_cases(Naive, 4)
    assert failed
    assert any(row.startswith("te-l4-spec") for row in failed)


def test_text_editor_l4_spec_cut_removes_span() -> None:
    cases = load_cases("text_editor", 4)
    spec = next(case for case in cases if case["id"] == "te-l4-spec")
    assert {"m": "cut", "a": [], "e": "world"} in spec["calls"]
    assert {"m": "get_text", "a": [], "e": "hello "} in spec["calls"]
