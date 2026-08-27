import json
from pathlib import Path

from honepad.cli import main
from honepad.session import load_session, remaining_s


def test_remaining_s_floors_at_zero() -> None:
    assert remaining_s(started_at=100, minutes=1, now=100) == 60
    assert remaining_s(started_at=100, minutes=1, now=200) == 0


def test_start_locks_higher_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    out = capsys.readouterr().out
    assert "unlocked=1" in out
    assert "remaining_s=" in out
    assert main(["start", "bank_system", "python3", "--level", "2"]) == 1
    assert "LOCKED: level 2" in capsys.readouterr().out


def test_run_pass_unlocks_next_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "stub"]) == 1
    stub_out = capsys.readouterr().out
    assert "UNLOCKED" not in stub_out
    assert load_session()["unlocked"] == 1
    assert main(["run", "bank_system"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3"]) == 0
    start_out = capsys.readouterr().out
    assert "LOCKED" not in start_out


def test_unlock_does_not_skip_a_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    seen = [1]
    for nxt in (2, 3, 4):
        assert main(["run", "bank_system"]) == 0
        out = capsys.readouterr().out
        assert f"UNLOCKED: level {nxt}" in out
        assert load_session()["unlocked"] == nxt
        seen.append(nxt)
    assert seen == [1, 2, 3, 4]
    assert main(["run", "bank_system"]) == 0
    last = capsys.readouterr().out
    assert "UNLOCKED" not in last
    assert load_session()["unlocked"] == 4


def test_timer_reads_session(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "javascript", "--minutes", "90", "--reset"]) == 0
    capsys.readouterr()
    assert main(["timer"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=" in out
    assert "NEXT:" in out
    left = int(out.split("remaining_s=")[1].split()[0])
    assert 0 < left <= 5400


def test_timer_remaining_after_mocked_clock(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    started = 1_700_000_000
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python3",
                "started_at": started,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    monkeypatch.setattr("honepad.session.time.time", lambda: started + 120)
    assert main(["timer"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=5280" in out
    assert "started_at=1700000000" in out
