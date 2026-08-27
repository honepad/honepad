import json
from pathlib import Path

from honepad.cli import main
from honepad.session import load_session, remaining_s


def test_remaining_s_floors_at_zero() -> None:
    assert remaining_s(started_at=100, minutes=1, now=100) == 60
    assert remaining_s(started_at=100, minutes=1, now=161) == 0
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
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3"]) == 0
    start_out = capsys.readouterr().out
    assert "LOCKED" not in start_out


def test_stub_runs_do_not_unlock_next_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "stub"]) == 1
    first = capsys.readouterr().out
    assert "UNLOCKED" not in first
    assert load_session()["unlocked"] == 1
    assert main(["run", "bank_system", "--kind", "stub"]) == 1
    second = capsys.readouterr().out
    assert "UNLOCKED" not in second
    assert load_session()["unlocked"] == 1


def test_unlock_does_not_skip_a_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    seen = [1]
    for nxt in (2, 3, 4):
        assert main(["run", "bank_system", "--kind", "solution"]) == 0
        out = capsys.readouterr().out
        assert f"UNLOCKED: level {nxt}" in out
        assert load_session()["unlocked"] == nxt
        seen.append(nxt)
    assert seen == [1, 2, 3, 4]
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    last = capsys.readouterr().out
    assert "UNLOCKED" not in last
    assert load_session()["unlocked"] == 4


def test_start_reset_clears_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    out = capsys.readouterr().out
    assert "unlocked=1" in out
    assert load_session()["unlocked"] == 1
    assert main(["start", "bank_system", "python3", "--level", "2"]) == 1
    assert "LOCKED: level 2" in capsys.readouterr().out


def test_start_different_problem_replaces_session(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "workers", "python3"]) == 0
    out = capsys.readouterr().out
    session = load_session()
    assert session is not None
    assert session["problem"] == "workers"
    assert session["unlocked"] == 1
    assert "unlocked=1" in out
    assert main(["start", "workers", "python3", "--level", "2"]) == 1
    assert "LOCKED: level 2" in capsys.readouterr().out


def test_start_same_problem_keeps_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "javascript"]) == 0
    out = capsys.readouterr().out
    session = load_session()
    assert session is not None
    assert session["unlocked"] == 2
    assert session["lang"] == "javascript"
    assert "unlocked=2" in out
    assert main(["start", "bank_system", "javascript", "--level", "2"]) == 0
    level_out = capsys.readouterr().out
    assert "LOCKED" not in level_out


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


def test_timer_expired_remaining_is_zero(monkeypatch, tmp_path: Path, capsys) -> None:
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
    monkeypatch.setattr("honepad.session.time.time", lambda: started + 90 * 60 + 5)
    assert main(["timer"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=0" in out


def test_start_level1_after_unlock_prints_l1_spec(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3", "--level", "1"]) == 0
    out = capsys.readouterr().out
    assert "create_account" in out
    assert "top_spenders" not in out
    assert "unlocked=2" in out


def test_start_without_level_prints_unlocked_spec(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3"]) == 0
    out = capsys.readouterr().out
    assert "top_spenders" in out
    assert "Bank system level 2" in out
    assert "unlocked=2" in out


def test_run_level4_with_session_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution", "--level", "4"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert "level<=4" in out


def test_run_without_session_defaults_to_python3_level4(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    assert main(["run", "bank_system"]) == 0
    out = capsys.readouterr().out
    assert "bank_system python3 level<=4" in out
    assert "UNLOCKED" not in out
    assert load_session() is None


def test_start_copies_work_file_away_from_pack(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    out = capsys.readouterr().out
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    assert work.is_file()
    assert f"WORK: {work}" in out
    assert "createAccount" in work.read_text(encoding="utf-8")
    assert not (work.parent / "solution.java").exists()
    assert "not expected to finish every level" in out.lower()


def test_start_keeps_edited_work_unless_reset(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    work.write_text("edited-by-candidate\n", encoding="utf-8")
    assert main(["start", "bank_system", "java"]) == 0
    capsys.readouterr()
    assert work.read_text(encoding="utf-8") == "edited-by-candidate\n"
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    assert "createAccount" in work.read_text(encoding="utf-8")


def test_run_with_session_uses_work_file(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system"]) == 1
    first = capsys.readouterr().out
    assert "UNLOCKED" not in first
    assert load_session()["unlocked"] == 1
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    solution = (
        Path(__file__).resolve().parents[1]
        / "langs"
        / "java"
        / "problems"
        / "bank_system"
        / "solution.java"
    )
    work.write_text(solution.read_text(encoding="utf-8"), encoding="utf-8")
    assert main(["run", "bank_system"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_locked_start_still_creates_work_file(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--level", "2"]) == 1
    out = capsys.readouterr().out
    assert "LOCKED: level 2" in out
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    assert work.is_file()
    assert main(["run", "bank_system"]) == 1
    run_out = capsys.readouterr().out
    assert "UNLOCKED" not in run_out
    assert load_session()["unlocked"] == 1


def test_missing_work_file_does_not_run_solution(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    work.unlink()
    assert main(["run", "bank_system"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1


def test_work_compile_error_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    work.write_text("this is not java\n", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "work.java" in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_timeout_java_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    work.write_text(
        """import java.util.List;

public class Simulation {
    public Simulation() {
        while (true) {}
    }

    public boolean createAccount(int timestamp, String accountId) {
        return false;
    }

    public Integer deposit(int timestamp, String accountId, int amount) {
        return null;
    }

    public Integer transfer(
            int timestamp, String sourceAccountId, String targetAccountId, int amount) {
        return null;
    }

    public List<String> topSpenders(int timestamp, int n) {
        return null;
    }

    public String pay(int timestamp, String accountId, int amount) {
        return null;
    }

    public String getPaymentStatus(int timestamp, String accountId, String payment) {
        return null;
    }

    public boolean mergeAccounts(int timestamp, String accountId1, String accountId2) {
        return false;
    }

    public Integer getBalance(int timestamp, String accountId, int timeAt) {
        return null;
    }
}
""",
        encoding="utf-8",
    )
    monkeypatch.setattr("honepad.runner.RUN_TIMEOUT_S", 1)
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "timed out" in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_syntax_error_python_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("not python\n", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_corrupt_session_run_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text("{", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert str(session_file) in out
    assert "Traceback" not in out


def test_corrupt_session_start_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text("{", encoding="utf-8")
    assert main(["start", "bank_system", "python3"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert str(session_file) in out
    assert "Traceback" not in out


def test_corrupt_session_timer_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text("{", encoding="utf-8")
    assert main(["timer"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert str(session_file) in out
    assert "Traceback" not in out


def test_incomplete_session_timer_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text("{}", encoding="utf-8")
    assert main(["timer"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "Traceback" not in out


def test_incomplete_session_run_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text("{}", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "Traceback" not in out


def test_run_with_session_prints_remaining_s(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=" in out
    assert "UNLOCKED" in out


def test_expired_run_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
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
    monkeypatch.setattr("honepad.session.time.time", lambda: started + 90 * 60 + 5)
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=0" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1


def test_run_level_zero_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    code = main(["run", "bank_system", "--lang", "python3", "--level", "0", "--kind", "solution"])
    assert code == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "\nOK\n" not in out
    assert not out.strip().endswith("OK")
    assert "UNLOCKED" not in out
