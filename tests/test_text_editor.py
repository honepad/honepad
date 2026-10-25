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
    assert {"m": "cursor", "a": [], "e": "6"} in spec["calls"]
    assert {"m": "get_text", "a": [], "e": "hello "} in spec["calls"]
    prose = (repo_root() / "problems" / "text_editor" / "spec" / "level4.md").read_text(
        encoding="utf-8"
    )
    assert 'cursor() -> "6"' in prose
    assert "The cursor moves to `start`" in prose
    assert "not undoable" in prose
    level3 = (repo_root() / "problems" / "text_editor" / "spec" / "level3.md").read_text(
        encoding="utf-8"
    )
    assert "They do not clear the redo stack." in " ".join(level3.split())
    level2 = (repo_root() / "problems" / "text_editor" / "spec" / "level2.md").read_text(
        encoding="utf-8"
    )
    assert "`insert` does not move the cursor" in level2


def test_text_editor_cut_must_move_cursor() -> None:
    official = _te_solution_class()

    class Naive(official):
        def cut(self) -> str:
            if self.sel is None or self.sel[0] == self.sel[1]:
                return "invalid_request"
            start, end = self.sel
            text = self.buf[start:end]
            self.buf = self.buf[:start] + self.buf[end:]
            self.clip = text
            self.sel = None
            return text

    failed = _replay_te_cases(Naive, 4)
    assert any(row.startswith("te-l4-spec ") and "cursor" in row for row in failed)


def test_text_editor_cut_must_keep_redo() -> None:
    official = _te_solution_class()

    class Naive(official):
        def cut(self) -> str:
            got = super().cut()
            self.redo_stack.clear()
            return got

    failed = _replay_te_cases(Naive, 4)
    assert any(row.startswith("te-l4-cut-keeps-redo") for row in failed)


def test_text_editor_undo_must_keep_clipboard() -> None:
    official = _te_solution_class()

    class Naive(official):
        def undo(self) -> str:
            got = super().undo()
            self.clip = ""
            return got

    failed = _replay_te_cases(Naive, 4)
    assert any(row.startswith("te-l4-undo-skips-clip") for row in failed)


def test_text_editor_undo_must_restore_cursor() -> None:
    official = _te_solution_class()

    class Naive(official):
        def undo(self) -> str:
            pos = self.pos
            got = super().undo()
            self.pos = pos
            return got

    failed = _replay_te_cases(Naive, 3)
    assert any(row.startswith("te-l3-undo-restores-cursor") for row in failed)


def test_text_editor_insert_must_not_shift_cursor() -> None:
    official = _te_solution_class()

    class Naive(official):
        def insert(self, pos: int, text: str) -> str:
            before = self.pos
            got = super().insert(pos, text)
            if got != "invalid_request" and pos <= before:
                self.pos = before + len(text)
            return got

    failed = _replay_te_cases(Naive, 2)
    assert any(row.startswith("te-l2-insert-keeps-cursor") for row in failed)
