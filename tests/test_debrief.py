"""Post-clock debrief of unlock and last run."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest

from honepad.catalog import repo_root
from honepad.cli import build_parser, main
from honepad.session import format_debrief, load_session, remaining_s, save_session, work_src
from honepad.term import invocation


def test_debrief_help_names_last_run_not_only_public(capsys) -> None:
    parser = build_parser()
    with pytest.raises(SystemExit) as excinfo:
        parser.parse_args(["debrief", "-h"])
    assert excinfo.value.code == 0
    out = capsys.readouterr().out
    assert "last run" in out.lower()
    assert "public or hidden" in out.lower()
    assert "last public run" not in out.lower()


def test_submit_time_up_prints_debrief(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--kind", "solution", "--confirm", "y"]) == 0
    out = capsys.readouterr().out
    assert "TIME UP" in out
    assert "UNLOCKED" not in out
    assert "DEBRIEF: bank_system python3 LEVEL 1/4" in out
    assert "used 90m left 0m" in out
    assert "last hidden through LEVEL 1 passed=" in out
    assert "remaining_s=" not in out
    assert "NEXT:" in out
    assert "start" in out
    saved = load_session()
    assert saved is not None
    assert saved["unlocked"] == 1
    assert saved["last_run"]["level"] == 1
    assert saved["last_run"]["passed"] > 0
    assert saved["last_run"]["failed"] == 0
    assert saved["last_run"]["hidden"] is True


def test_submit_public_fail_on_time_up_still_prints_debrief(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--kind", "stub", "--confirm", "y"]) == 1
    out = capsys.readouterr().out
    assert "TIME UP" in out
    assert "DEBRIEF:" in out
    assert "NEXT:" in out
    assert "UNLOCKED" not in out


def test_submit_hidden_load_error_on_time_up_still_prints_debrief(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )

    def boom(*_a, **_k):
        raise ValueError("hidden.json: bad")

    monkeypatch.setattr("honepad.cli.load_hidden_cases", boom)
    assert main(["submit", "bank_system", "--kind", "solution", "--confirm", "y"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "hidden.json: bad" in out
    assert "TIME UP" in out
    assert "DEBRIEF: bank_system python3 LEVEL 1/4" in out
    assert "last hidden through LEVEL 1 passed=0 failed=" in out
    assert "NEXT:" in out
    assert "start" in out
    saved = load_session()
    assert saved is not None
    assert saved["unlocked"] == 1
    assert saved["last_run"]["failed"] >= 1
    assert saved["last_run"]["passed"] == 0
    assert saved["last_run"]["hidden"] is True


def test_debrief_command_does_not_restart_clock(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "workers",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 2,
                "last_run": {"level": 2, "passed": 4, "failed": 1},
            }
        )
        + "\n",
        encoding="utf-8",
    )
    before = json.loads(session_file.read_text(encoding="utf-8"))
    assert main(["debrief"]) == 0
    out = capsys.readouterr().out
    assert "DEBRIEF: workers python3 LEVEL 2/4" in out
    assert "used 90m left 0m" in out
    assert "last through LEVEL 2 passed=4 failed=1" in out
    assert "remaining_s=" not in out
    assert f"NEXT: {invocation()} start" in out
    after = json.loads(session_file.read_text(encoding="utf-8"))
    assert after["started_at"] == before["started_at"]
    assert remaining_s(int(after["started_at"]), int(after["minutes"])) == 0


def test_debrief_mid_session_keeps_clock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    session = load_session()
    assert session is not None
    started = int(session["started_at"])
    assert main(["debrief"]) == 0
    out = capsys.readouterr().out
    assert "DEBRIEF: workers python3 LEVEL 1/4" in out
    assert "last run: none" in out
    assert "remaining_s=" not in out
    assert "NEXT:" not in out
    again = load_session()
    assert again is not None
    assert int(again["started_at"]) == started


def test_debrief_unreadable_session_is_fail_not_traceback(
    monkeypatch, tmp_path: Path, capsys
) -> None:
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
    session_file.chmod(0o000)
    try:
        assert main(["debrief"]) == 1
    finally:
        session_file.chmod(0o644)
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "Traceback" not in out


def test_debrief_without_session_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    assert main(["debrief"]) == 1
    out = capsys.readouterr().out
    assert "FAIL: no session" in out
    assert "NEXT:" in out


def test_format_debrief_omits_remaining_s_token() -> None:
    text = format_debrief(
        {
            "problem": "workers",
            "lang": "python3",
            "started_at": 100,
            "minutes": 90,
            "unlocked": 2,
            "last_run": {"level": 2, "passed": 3, "failed": 0},
        },
        now=100 + 30 * 60,
    )
    assert "remaining_s" not in text
    assert "used 30m left 60m" in text
    assert "last through LEVEL 2 passed=3 failed=0" in text
    assert "last hidden through" not in text


def test_format_debrief_says_hidden_when_last_run_hidden() -> None:
    text = format_debrief(
        {
            "problem": "workers",
            "lang": "python3",
            "started_at": 100,
            "minutes": 90,
            "unlocked": 1,
            "last_run": {"level": 1, "passed": 0, "failed": 1, "hidden": True},
        },
        now=100 + 90 * 60,
    )
    assert "last hidden through LEVEL 1 passed=0 failed=1" in text
    assert "last through LEVEL" not in text


def test_save_and_load_keeps_hidden_last_run(monkeypatch, tmp_path: Path) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    save_session(
        {
            "problem": "workers",
            "lang": "python3",
            "started_at": 1_700_000_000,
            "minutes": 90,
            "unlocked": 1,
            "last_run": {"level": 1, "passed": 2, "failed": 1, "hidden": True},
        }
    )
    loaded = load_session()
    assert loaded is not None
    assert loaded["last_run"]["hidden"] is True
    assert "last hidden through LEVEL 1 passed=2 failed=1" in format_debrief(
        loaded, now=1_700_000_000
    )


def test_debrief_after_hidden_fail_says_hidden(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    capsys.readouterr()
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
    capsys.readouterr()
    assert main(["debrief"]) == 0
    out = capsys.readouterr().out
    assert "last hidden through LEVEL 1 passed=0 failed=1" in out
    saved = load_session()
    assert saved is not None
    assert saved["last_run"]["hidden"] is True


def test_debrief_after_public_run_does_not_say_hidden(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["run", "workers", "--kind", "work"]) == 1
    capsys.readouterr()
    assert main(["debrief"]) == 0
    out = capsys.readouterr().out
    assert "last through LEVEL 1 passed=" in out
    assert "last hidden through" not in out
    saved = load_session()
    assert saved is not None
    assert saved["last_run"].get("hidden") is not True


def test_time_up_after_public_run_does_not_say_hidden(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    dest = work_src("bank_system", "python3")
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(
        repo_root() / "langs" / "python3" / "problems" / "bank_system" / "solution.py",
        dest,
    )
    assert main(["run", "bank_system", "--kind", "work"]) == 0
    out = capsys.readouterr().out
    assert "TIME UP" in out
    assert "last through LEVEL 1 passed=" in out
    assert "last hidden through" not in out
    assert "NEXT:" in out
    assert "start" in out
    saved = load_session()
    assert saved is not None
    assert saved["last_run"].get("hidden") is not True
