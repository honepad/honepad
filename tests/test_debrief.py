"""Post-clock debrief of unlock and last run."""

from __future__ import annotations

import json
from pathlib import Path

from honepad.cli import main
from honepad.session import format_debrief, load_session, remaining_s


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
    assert "last through LEVEL 1 passed=" in out
    assert "remaining_s=" not in out
    saved = load_session()
    assert saved is not None
    assert saved["unlocked"] == 1
    assert saved["last_run"]["level"] == 1
    assert saved["last_run"]["passed"] > 0
    assert saved["last_run"]["failed"] == 0


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
    again = load_session()
    assert again is not None
    assert int(again["started_at"]) == started


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
