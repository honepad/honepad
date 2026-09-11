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


def test_hidden_methods_stay_inside_unlocked_public_api() -> None:
    from honepad.catalog import problems
    from honepad.session import max_level
    from honepad.workstub import methods_through_level

    for problem in problems():
        for n in range(1, max_level(problem) + 1):
            allowed = methods_through_level(problem, n, "snake")
            for case in load_hidden_cases(problem, n):
                used = {str(call["m"]) for call in case["calls"]}
                assert used <= allowed, (problem, n, case["id"], used - allowed)


def test_hook_runners_accept_cases_kwarg() -> None:
    import inspect

    from honepad.runner import _HOOK_RUNNERS

    assert _HOOK_RUNNERS
    for name, fn in _HOOK_RUNNERS.items():
        assert "cases" in inspect.signature(fn).parameters, name


def test_ambient_honepad_cases_does_not_hijack_public_python(monkeypatch, tmp_path: Path) -> None:
    bogus = tmp_path / "empty.json"
    bogus.write_text("[]\n", encoding="utf-8")
    monkeypatch.setenv("HONEPAD_CASES", str(bogus))
    report = run("bank_system", "python3", 1, "solution")
    assert report.ok, report.failed
    assert report.passed > 0


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


def test_hidden_ids_strictly_grow_l1_to_l4() -> None:
    from honepad.catalog import problems
    from honepad.session import max_level
    from honepad.workstub import methods_through_level

    for problem in problems():
        prev_ids: set[str] = set()
        for n in range(1, max_level(problem) + 1):
            cases = load_hidden_cases(problem, n)
            ids = {str(case["id"]) for case in cases}
            assert ids, (problem, n)
            if n > 1:
                assert prev_ids < ids, (problem, n, sorted(prev_ids), sorted(ids))
                new_methods = methods_through_level(problem, n, "snake") - methods_through_level(
                    problem, n - 1, "snake"
                )
                for case in cases:
                    if int(case["level"]) != n:
                        continue
                    used = {str(call["m"]) for call in case["calls"]}
                    assert used & new_methods, (problem, case["id"], used, new_methods)
            prev_ids = ids


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


def test_official_solution_passes_hidden_at_every_level() -> None:
    from honepad.catalog import problems
    from honepad.session import max_level

    for problem in problems():
        for n in range(1, max_level(problem) + 1):
            hidden = load_hidden_cases(problem, n)
            report = run(problem, "python3", n, "solution", cases=hidden)
            assert report.ok, (problem, n, report.failed)
            assert report.passed == len(hidden)


_HARDCODED_BANK_L2 = """\
class Simulation:
    def __init__(self):
        self.accounts = {}

    def create_account(self, timestamp, account_id):
        if account_id in self.accounts:
            return False
        self.accounts[account_id] = 0
        return True

    def deposit(self, timestamp, account_id, amount):
        if account_id not in self.accounts:
            return None
        self.accounts[account_id] += amount
        return self.accounts[account_id]

    def transfer(self, timestamp, source_account_id, target_account_id, amount):
        if source_account_id not in self.accounts or target_account_id not in self.accounts:
            return None
        if source_account_id == target_account_id:
            return None
        if self.accounts[source_account_id] < amount:
            return None
        self.accounts[source_account_id] -= amount
        self.accounts[target_account_id] += amount
        return self.accounts[source_account_id]

    def top_spenders(self, timestamp, n):
        # Public L2 expects only. Hidden L2 uses other ids and must fail.
        public = {
            frozenset(): [],
            frozenset(["acc1"]): ["acc1(500)"],
            frozenset(["acc1", "acc2"]): ["acc1(500)", "acc2(0)"],
            frozenset(["acc1", "acc2", "acc3"]): ["acc1(500)", "acc2(500)", "acc3(300)"],
        }
        if n <= 0:
            return []
        return public.get(frozenset(self.accounts), [])[:n]
"""


def test_hardcoded_public_l2_fails_hidden_l2(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest = work_src("bank_system", "python3")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(_HARDCODED_BANK_L2, encoding="utf-8")
    public = load_cases("bank_system", 2)
    public_report = run("bank_system", "python3", 2, "work", cases=public)
    assert public_report.ok, public_report.failed
    hidden = load_hidden_cases("bank_system", 2)
    hidden_report = run("bank_system", "python3", 2, "work", cases=hidden)
    assert not hidden_report.ok


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
    assert session["last_run"]["failed"] >= 1
    assert session["last_run"]["passed"] == 0


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
    assert "TIME UP" in out
    assert "DEBRIEF:" in out
    session = load_session()
    assert session is not None
    assert session["unlocked"] == 1
    assert session["last_run"]["failed"] >= 1


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
