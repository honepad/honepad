"""Hidden traces run on submit, not on practice run."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.runner import run
from honepad.session import load_session, work_src
from honepad.traces import load_cases, load_hidden_cases


def _copy_official_python_work(problem: str) -> None:
    src = repo_root() / "langs" / "python3" / "problems" / problem / "solution.py"
    dest = work_src(problem, "python3")
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)


def test_every_catalog_problem_has_hidden_l1_and_l4() -> None:
    from honepad.catalog import problems
    from honepad.session import max_level
    from honepad.workstub import methods_through_level

    for problem in problems():
        l1 = load_hidden_cases(problem, 1)
        hidden = load_hidden_cases(problem, max_level(problem))
        assert l1, problem
        assert hidden, problem
        assert {case["id"] for case in l1} <= {case["id"] for case in hidden}
        allowed = methods_through_level(problem, 1, "snake")
        for case in l1:
            used = {str(call["m"]) for call in case["calls"]}
            assert used <= allowed, (problem, case["id"], used - allowed)


def test_hidden_l4_includes_hidden_l1() -> None:
    l1 = load_hidden_cases("workers", 1)
    l4 = load_hidden_cases("workers", 4)
    assert l1
    assert {case["id"] for case in l1} <= {case["id"] for case in l4}
    assert any(case["id"] == "hid-l4-bonus-before-session" for case in l4)
    assert all(int(case["level"]) <= 4 for case in l4)


def test_public_cases_unchanged_by_hidden() -> None:
    from honepad.catalog import problems

    for problem in problems():
        public_ids = {case["id"] for case in load_cases(problem, 4)}
        hidden_ids = {case["id"] for case in load_hidden_cases(problem, 4)}
        assert public_ids.isdisjoint(hidden_ids), problem


def test_official_solution_passes_hidden() -> None:
    from honepad.catalog import problems

    for problem in problems():
        hidden = load_hidden_cases(problem, 4)
        report = run(problem, "python3", 4, "solution", cases=hidden)
        assert report.ok, (problem, report.failed)
        assert report.passed == len(hidden)


def test_practice_run_stays_public_only(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    capsys.readouterr()
    _copy_official_python_work("workers")
    assert main(["run", "workers", "--kind", "work"]) == 0
    out = capsys.readouterr().out
    assert "through LEVEL 1" in out
    assert "hidden through LEVEL" not in out
    assert "hid-l1-two-workers" not in out


def test_submit_hidden_load_error_is_fail_not_traceback(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    capsys.readouterr()

    def boom(*_a, **_k):
        raise ValueError("hidden.json: bad")

    monkeypatch.setattr("honepad.cli.load_hidden_cases", boom)
    assert main(["submit", "workers", "--kind", "solution", "--confirm", "y"]) == 1
    captured = capsys.readouterr()
    captured = captured.out + captured.err
    assert "FAIL:" in captured
    assert "Traceback" not in captured
    assert "hidden.json: bad" in captured
    session = load_session()
    assert session is not None
    assert session["unlocked"] == 1


def test_submit_hidden_fail_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "workers",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(
        "honepad.cli.load_hidden_cases",
        lambda *_a, **_k: [
            {
                "id": "hid-fail",
                "level": 1,
                "calls": [{"m": "get", "a": ["missing"], "e": "999"}],
            }
        ],
    )
    assert main(["submit", "workers", "--kind", "solution", "--confirm", "y"]) == 1
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert "hid-fail" in out
    assert "hidden through LEVEL" in out
    assert "999" not in out
    assert "expected=" not in out
    session = load_session()
    assert session is not None
    assert session["unlocked"] == 1


def test_submit_solution_runs_hidden_and_can_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["submit", "workers", "--kind", "solution", "--confirm", "y"]) == 0
    out = capsys.readouterr().out
    assert "hidden through LEVEL 1" in out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_submit_work_runs_hidden_after_public_pass(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    capsys.readouterr()
    _copy_official_python_work("workers")
    assert main(["submit", "workers", "--kind", "work", "--confirm", "y"]) == 0
    out = capsys.readouterr().out
    assert "hidden through LEVEL 1" in out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2
