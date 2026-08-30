import io
import json
import os
import shutil
import sys
from pathlib import Path

import pytest

from honepad.catalog import language, problems, repo_root
from honepad.cli import main
from honepad.runner import _RUNNERS
from honepad.session import ensure_work_copy, load_session, remaining_s, save_session, work_src
from honepad.workstub import (
    _java_method,
    class_name_for,
    declares_class,
    merge_unlocked_methods,
    methods_through_level,
    naming_for,
)


def test_class_name_for_covers_every_catalog_problem() -> None:
    ids = problems()
    assert ids
    for problem in ids:
        name = class_name_for(problem)
        assert name
        assert name.isidentifier()


def test_java_method_includes_leading_javadoc() -> None:
    stub = (
        Path(__file__).resolve().parents[1]
        / "langs"
        / "java"
        / "problems"
        / "bank_system"
        / "stub.java"
    ).read_text(encoding="utf-8")
    block = _java_method(stub, "topSpenders")
    assert block is not None
    assert block.lstrip().startswith("/**")
    assert "id(outgoing)" in block
    assert "public List<String> topSpenders" in block


def test_bank_merge_stub_names_java_params() -> None:
    stub = (
        Path(__file__).resolve().parents[1]
        / "langs"
        / "java"
        / "problems"
        / "bank_system"
        / "stub.java"
    ).read_text(encoding="utf-8")
    block = _java_method(stub, "mergeAccounts")
    assert block is not None
    assert "Move drop onto keep" not in block
    assert "{@code accountId1}" in block
    assert "{@code accountId2}" in block
    py = (
        Path(__file__).resolve().parents[1]
        / "langs"
        / "python3"
        / "problems"
        / "bank_system"
        / "stub.py"
    ).read_text(encoding="utf-8")
    assert "Move drop onto keep" not in py
    assert "account_id_1" in py
    assert "account_id_2" in py


def test_start_replaces_old_merge_javadoc(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    old = (
        "    /**\n"
        "     * Move drop onto keep, then delete drop. Returns false if either id\n"
        "     * is missing or they are the same.\n"
        "     */\n"
        "    public boolean mergeAccounts(int timestamp, String accountId1, String accountId2) {\n"
        "        process(timestamp);\n"
        "        return false;\n"
        "    }\n"
    )
    text = work.read_text(encoding="utf-8")
    close = text.rfind("}")
    work.write_text(text[:close] + old + "}\n", encoding="utf-8")
    ensure_work_copy("bank_system", "java", reset=False, level=4)
    after = work.read_text(encoding="utf-8")
    assert "Move drop onto keep" not in after
    assert "{@code accountId1}" in after
    assert "{@code accountId2}" in after
    assert "process(timestamp)" in after


def test_remaining_s_floors_at_zero() -> None:
    assert remaining_s(started_at=100, minutes=1, now=100) == 60
    assert remaining_s(started_at=100, minutes=1, now=161) == 0
    assert remaining_s(started_at=100, minutes=1, now=200) == 0


def test_start_locks_higher_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    out = capsys.readouterr().out
    assert "LEVEL 1" in out
    assert "remaining_s=" in out
    assert main(["start", "bank_system", "python3", "--level", "2"]) == 1
    assert "LOCKED: LEVEL 2" in capsys.readouterr().out


def test_run_pass_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "stub"]) == 1
    stub_out = capsys.readouterr().out
    assert "UNLOCKED" not in stub_out
    assert load_session()["unlocked"] == 1
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert "2 submit" in out
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    src = (
        Path(__file__).resolve().parents[1]
        / "langs"
        / "python3"
        / "problems"
        / "bank_system"
        / "solution.py"
    )
    work.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    assert main(["run", "bank_system"]) == 0
    work_out = capsys.readouterr().out
    assert "UNLOCKED" not in work_out
    assert load_session()["unlocked"] == 1
    assert "2 submit" in work_out


def test_submit_pass_unlocks_next_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "stub"]) == 1
    stub_out = capsys.readouterr().out
    assert "UNLOCKED" not in stub_out
    assert load_session()["unlocked"] == 1
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3"]) == 0
    start_out = capsys.readouterr().out
    assert "LOCKED" not in start_out


def test_run_submit_flag_unlocks(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution", "--submit"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_submit_unlocks_when_workspace_write_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    src = repo_root() / "langs" / "python3" / "problems" / "bank_system" / "solution.py"
    work.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")

    def boom(*_args: object, **_kwargs: object) -> None:
        raise OSError("workspace boom")

    monkeypatch.setattr("honepad.cli.write_workspace", boom)
    code = main(["run", "bank_system", "--submit"])
    out = capsys.readouterr().out
    assert code == 0
    assert load_session()["unlocked"] == 2
    assert "def top_spenders" in work.read_text(encoding="utf-8")
    assert "Traceback" not in out
    assert "UNLOCKED: level 2" in out
    assert "OK" in out
    assert "NOTE:" in out
    assert "workspace boom" in out


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
        assert main(["submit", "bank_system", "--kind", "solution"]) == 0
        out = capsys.readouterr().out
        assert f"UNLOCKED: level {nxt}" in out
        assert load_session()["unlocked"] == nxt
        seen.append(nxt)
    assert seen == [1, 2, 3, 4]
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    last = capsys.readouterr().out
    assert "UNLOCKED" not in last
    assert load_session()["unlocked"] == 4


def test_start_reset_clears_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    out = capsys.readouterr().out
    assert "LEVEL 1" in out
    assert load_session()["unlocked"] == 1
    assert main(["start", "bank_system", "python3", "--level", "2"]) == 1
    assert "LOCKED: LEVEL 2" in capsys.readouterr().out


def test_start_different_problem_replaces_session(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "workers", "python3"]) == 0
    out = capsys.readouterr().out
    session = load_session()
    assert session is not None
    assert session["problem"] == "workers"
    assert session["unlocked"] == 1
    assert "LEVEL 1" in out
    assert main(["start", "workers", "python3", "--level", "2"]) == 1
    assert "LOCKED: LEVEL 2" in capsys.readouterr().out


def test_start_same_problem_keeps_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "javascript"]) == 0
    out = capsys.readouterr().out
    session = load_session()
    assert session is not None
    assert session["unlocked"] == 2
    assert session["lang"] == "javascript"
    assert "LEVEL 2" in out
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
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3", "--level", "1"]) == 0
    out = capsys.readouterr().out
    assert "create_account" in out
    assert "top_spenders" not in out
    assert "LEVEL 2" in out


def test_start_without_level_prints_unlocked_spec(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3"]) == 0
    out = capsys.readouterr().out
    assert "top_spenders" in out
    assert "Bank system level 2" in out
    assert "LEVEL 2" in out


def test_run_level4_with_session_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution", "--level", "4"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert "through LEVEL 4" in out


def test_run_without_session_defaults_to_python3_level4(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    assert main(["run", "bank_system"]) == 0
    out = capsys.readouterr().out
    assert "bank_system python3 through LEVEL 4" in out
    assert "UNLOCKED" not in out
    assert load_session() is None


def test_run_kind_work_without_session(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    assert main(["run", "bank_system", "--kind", "work", "--lang", "python3"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "work file missing" in out or "work.py" in out
    assert "UNLOCKED" not in out
    assert "\nOK\n" not in out
    assert not out.strip().endswith("OK")
    assert "through LEVEL 4 passed=" not in out
    assert load_session() is None


def test_run_kind_work_problem_mismatch(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--reset"]) == 0
    capsys.readouterr()
    session = load_session()
    assert session is not None
    assert session["problem"] == "workers"
    unlocked = session["unlocked"]
    assert main(["run", "bank_system", "--kind", "work"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "work file missing" in out
    assert "bank_system" in out
    assert "UNLOCKED" not in out
    assert "\nOK\n" not in out
    assert not out.strip().endswith("OK")
    assert "through LEVEL 4 passed=" not in out
    after = load_session()
    assert after is not None
    assert after["problem"] == "workers"
    assert after["unlocked"] == unlocked


@pytest.mark.parametrize("argv", (["submit", "bank_system"], ["run", "bank_system", "--submit"]))
def test_submit_without_session_does_not_run_solution(
    monkeypatch, tmp_path: Path, capsys, argv: list[str]
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    code = main(argv)
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL:" in out
    assert "no session" in out
    assert "NEXT:" in out
    assert "start" in out
    assert "UNLOCKED" not in out
    assert "\nOK\n" not in out
    assert not out.strip().endswith("OK")
    assert "through LEVEL" not in out
    assert load_session() is None


@pytest.mark.parametrize("argv", (["submit", "bank_system"], ["run", "bank_system", "--submit"]))
def test_submit_wrong_problem_does_not_run_solution(
    monkeypatch, tmp_path: Path, capsys, argv: list[str]
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--reset", "--no-console"]) == 0
    before = load_session()
    assert before is not None
    assert before["problem"] == "workers"
    unlocked = before["unlocked"]
    started = before["started_at"]
    capsys.readouterr()
    code = main(argv)
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL:" in out
    assert "no session" in out or "mismatch" in out
    assert "NEXT:" in out
    assert "start" in out
    assert "UNLOCKED" not in out
    assert "\nOK\n" not in out
    assert not out.strip().endswith("OK")
    assert "through LEVEL" not in out
    after = load_session()
    assert after is not None
    assert after["problem"] == "workers"
    assert after["unlocked"] == unlocked
    assert after["started_at"] == started


def test_start_copies_work_file_away_from_pack(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    out = capsys.readouterr().out
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    assert work.is_file()
    assert not (work.parent / "work.java").exists()
    assert "WORK:" in out
    assert str(work) in out
    assert "file://" in out
    assert "createAccount" in work.read_text(encoding="utf-8")
    assert "mergeAccounts" not in work.read_text(encoding="utf-8")
    assert "topSpenders" not in work.read_text(encoding="utf-8")
    assert not (work.parent / "solution.java").exists()
    assert "not expected to finish every level" in out.lower()


def test_legacy_java_work_file_migrates_to_class_name(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest_dir = tmp_path / "work" / "bank_system" / "java"
    dest_dir.mkdir(parents=True)
    legacy = dest_dir / "work.java"
    dest = dest_dir / "Simulation.java"
    legacy.write_text("marker-keep-me\npublic class Simulation {}\n", encoding="utf-8")
    assert not dest.exists()
    assert main(["start", "bank_system", "java"]) == 0
    capsys.readouterr()
    assert dest.is_file()
    assert "marker-keep-me" in dest.read_text(encoding="utf-8")
    assert not legacy.exists()


def test_legacy_java_leftover_dropped_when_dest_exists(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest_dir = tmp_path / "work" / "bank_system" / "java"
    dest_dir.mkdir(parents=True)
    dest = dest_dir / "Simulation.java"
    leftover = dest_dir / "work.java"
    dest.write_text("live-marker\n", encoding="utf-8")
    leftover.write_text("dead-marker\n", encoding="utf-8")
    found = work_src("bank_system", "java")
    assert found == dest
    assert dest.read_text(encoding="utf-8") == "live-marker\n"
    assert not leftover.exists()


def test_legacy_java_rename_oserror_copies_then_unlinks(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest_dir = tmp_path / "work" / "bank_system" / "java"
    dest_dir.mkdir(parents=True)
    leftover = dest_dir / "work.java"
    dest = dest_dir / "Simulation.java"
    leftover.write_text("marker-rename-fallback\n", encoding="utf-8")
    assert not dest.exists()

    def _fail_rename(self: Path, target: object) -> Path:
        raise OSError("cross-device")

    monkeypatch.setattr(Path, "rename", _fail_rename)
    found = work_src("bank_system", "java")
    assert found == dest
    assert dest.is_file()
    assert dest.read_text(encoding="utf-8") == "marker-rename-fallback\n"
    assert not leftover.exists()
    copied = ensure_work_copy("bank_system", "java", reset=False, level=1)
    assert copied == dest
    assert dest.read_text(encoding="utf-8") == "marker-rename-fallback\n"
    assert not leftover.exists()


def test_start_python_work_hides_later_methods(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def create_account(" in text
    assert "def merge_accounts(" not in text
    assert "def top_spenders(" not in text


def test_unlock_appends_next_level_methods(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    text = work.read_text(encoding="utf-8")
    work.write_text(text.replace("return false;", "return false; // keep-me", 1), encoding="utf-8")
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    after = work.read_text(encoding="utf-8")
    assert "keep-me" in after
    assert "topSpenders" in after
    assert "import java.util.List" in after
    assert "mergeAccounts" not in after
    assert "id(outgoing)" in after
    assert '["acc1(500)", "acc2(0)"]' in after


def test_start_java_work_has_docs_only_for_unlocked(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    text = work.read_text(encoding="utf-8")
    assert "/**" in text
    assert "Returns true if created" in text
    assert "topSpenders" not in text
    assert "id(outgoing)" not in text
    assert "paymentN" not in text


def test_start_python_work_has_docs_only_for_unlocked(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert '"""Create an account.' in text
    assert "def top_spenders(" not in text
    assert "id(outgoing)" not in text


def test_start_keeps_edited_work_unless_reset(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
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
    assert "createAccount(1, 'acc1')" in first or 'createAccount(1, "acc1")' in first
    assert "expected=True" in first or "expected=true" in first
    assert "WORK:" in first
    assert load_session()["unlocked"] == 1
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
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
    run_out = capsys.readouterr().out
    assert "UNLOCKED" not in run_out
    assert load_session()["unlocked"] == 1
    assert "2 submit" in run_out
    assert main(["submit", "bank_system"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_locked_start_still_creates_work_file(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--level", "2"]) == 1
    out = capsys.readouterr().out
    assert "LOCKED: LEVEL 2" in out
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    assert work.is_file()
    assert main(["run", "bank_system"]) == 1
    run_out = capsys.readouterr().out
    assert "UNLOCKED" not in run_out
    assert load_session()["unlocked"] == 1


def test_missing_work_file_does_not_run_solution(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
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
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    work.write_text("this is not java\n", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert str(work) in out
    lowered = out.lower()
    assert "error" in lowered or "expected" in lowered or "javac" in lowered
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


@pytest.mark.skipif(
    shutil.which("cc") is None and shutil.which("gcc") is None,
    reason="cc/gcc not found",
)
def test_work_compile_error_prints_c_work_path(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "c", "--reset"]) == 0
    capsys.readouterr()
    work = work_src("bank_system", "c")
    work.write_text("this is not c\n", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert str(work) in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_timeout_java_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
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
    assert "java" in out
    assert str(work) in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_timeout_python_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(
        "class Simulation:\n    def __init__(self):\n        while True:\n            pass\n",
        encoding="utf-8",
    )
    monkeypatch.setattr("honepad.runner.RUN_TIMEOUT_S", 1)
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "timed out" in out
    assert "python3" in out
    assert work.name in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_timeout_javascript_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    work.write_text(
        """class Simulation {
  constructor() { while (true) {} }
  createAccount(timestamp, account_id) { return false; }
  deposit(timestamp, account_id, amount) { return null; }
  transfer(timestamp, source_account_id, target_account_id, amount) { return null; }
}
module.exports = { Simulation };
""",
        encoding="utf-8",
    )
    monkeypatch.setattr("honepad.runner.RUN_TIMEOUT_S", 1)
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "timed out" in out
    assert "javascript" in out
    assert work.name in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_syntax_error_python_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("def (\n", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "work.py" in out
    assert "SyntaxError" in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_print_then_missing_class_prints_load_error(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("print('hi')\n", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "work.py" in out
    assert "Simulation" in out
    assert "invalid JSON" not in out
    assert "Traceback" not in out
    assert "UNLOCKED" not in out


def test_work_missing_method_python_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("class Simulation:\n    pass\n", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL" in out
    assert "create_account" in out
    assert "exc:AttributeError" in out
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


def test_start_javascript_work_hides_later_methods(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    text = work.read_text(encoding="utf-8")
    assert "createAccount(" in text
    assert "deposit(" in text
    assert "transfer(" in text
    assert "topSpenders(" not in text
    assert "mergeAccounts(" not in text
    assert "module.exports" in text


def test_start_typescript_work_hides_later_methods(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "typescript", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "typescript" / "work.ts"
    text = work.read_text(encoding="utf-8")
    assert "createAccount(" in text
    assert "topSpenders(" not in text
    assert "getBalance(" not in text
    assert "module.exports" in text


def test_unlock_javascript_appends_next_methods(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    text = work.read_text(encoding="utf-8")
    work.write_text(text.replace("not implemented", "keep-me", 1), encoding="utf-8")
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    after = work.read_text(encoding="utf-8")
    assert "keep-me" in after
    assert "topSpenders(" in after
    assert "mergeAccounts(" not in after
    assert "module.exports" in after


def test_existing_java_work_gets_missing_docs(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest_dir = tmp_path / "work" / "bank_system" / "java"
    dest_dir.mkdir(parents=True)
    work = dest_dir / "Simulation.java"
    work.write_text(
        """public class Simulation {
    public Simulation() {}

    public boolean createAccount(int timestamp, String accountId) {
        return true;
    }

    public Integer deposit(int timestamp, String accountId, int amount) {
        return amount;
    }

    public Integer transfer(
            int timestamp, String sourceAccountId, String targetAccountId, int amount) {
        return null;
    }
}
""",
        encoding="utf-8",
    )
    copied = ensure_work_copy("bank_system", "java", reset=False, level=1)
    text = copied.read_text(encoding="utf-8")
    assert "return true;" in text
    assert "return amount;" in text
    assert "Returns true if created" in text
    assert "Add funds" in text
    assert "topSpenders" not in text


def test_existing_python_work_gets_missing_docs(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest_dir = tmp_path / "work" / "bank_system" / "python3"
    dest_dir.mkdir(parents=True)
    work = dest_dir / "work.py"
    work.write_text(
        """class Simulation:
    def __init__(self):
        pass

    def create_account(self, timestamp, account_id):
        return True

    def deposit(self, timestamp, account_id, amount):
        return amount

    def transfer(self, timestamp, source_account_id, target_account_id, amount):
        return None
""",
        encoding="utf-8",
    )
    copied = ensure_work_copy("bank_system", "python3", reset=False, level=1)
    text = copied.read_text(encoding="utf-8")
    assert "return True" in text
    assert "return amount" in text
    assert '"""Create an account.' in text
    assert "def top_spenders(" not in text


def test_existing_docs_are_not_replaced(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest_dir = tmp_path / "work" / "bank_system" / "java"
    dest_dir.mkdir(parents=True)
    work = dest_dir / "Simulation.java"
    work.write_text(
        """public class Simulation {
    public Simulation() {}

    /** Candidate note. */
    public boolean createAccount(int timestamp, String accountId) {
        return true;
    }

    public Integer deposit(int timestamp, String accountId, int amount) {
        return amount;
    }

    public Integer transfer(
            int timestamp, String sourceAccountId, String targetAccountId, int amount) {
        return null;
    }
}
""",
        encoding="utf-8",
    )
    copied = ensure_work_copy("bank_system", "java", reset=False, level=1)
    text = copied.read_text(encoding="utf-8")
    assert "Candidate note." in text
    assert "Returns true if created" not in text
    assert "Add funds" in text
    assert "return true;" in text


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
    assert str(session_file) in out
    assert "missing" in out
    assert "Traceback" not in out


def test_incomplete_session_run_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text("{}", encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert str(session_file) in out
    assert "missing" in out
    assert "Traceback" not in out


def test_run_with_session_prints_remaining_s(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=" in out
    assert "UNLOCKED" not in out
    assert "2 submit" in out
    assert load_session()["unlocked"] == 1
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    submit_out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in submit_out
    assert load_session()["unlocked"] == 2


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
    through = [ln for ln in out.splitlines() if "through LEVEL" in ln]
    assert through
    assert all("remaining_s=" not in ln for ln in through)
    assert "UNLOCKED" not in out
    assert "TIME UP" in out
    assert "q then" in out
    assert load_session()["unlocked"] == 1


def test_start_after_expiry_restarts_clock_keeps_work(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    work.write_text(
        work.read_text(encoding="utf-8").replace("return false;", "return false; // keep-me", 1),
        encoding="utf-8",
    )
    session = load_session()
    assert session is not None
    session["unlocked"] = 2
    session["started_at"] = 1_700_000_000
    session_file.write_text(json.dumps(session, indent=2) + "\n", encoding="utf-8")
    now = 1_700_000_000 + 90 * 60 + 5
    monkeypatch.setattr("honepad.session.time.time", lambda: now)
    assert main(["start", "bank_system", "java"]) == 0
    out = capsys.readouterr().out
    after = load_session()
    assert after is not None
    assert after["unlocked"] == 2
    assert after["started_at"] == now
    assert remaining_s(int(after["started_at"]), int(after["minutes"]), now) == 5400
    assert "keep-me" in work.read_text(encoding="utf-8")
    assert "NOTE: previous clock was 0. New clock started. Work file kept." in out
    assert "remaining_s=5400" in out
    on_disk = json.loads(session_file.read_text(encoding="utf-8"))
    assert "clock_restarted" not in after
    assert "clock_restarted" not in on_disk


def test_start_while_time_remains_keeps_started_at(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    clock = {"now": 1_700_000_000}

    def _now() -> float:
        return float(clock["now"])

    monkeypatch.setattr("honepad.session.time.time", _now)
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    first = load_session()
    assert first is not None
    started = int(first["started_at"])
    assert started == 1_700_000_000
    clock["now"] = started + 30
    assert main(["start", "bank_system", "python3", "--no-console"]) == 0
    capsys.readouterr()
    after = load_session()
    assert after is not None
    assert after["started_at"] == started
    assert after["unlocked"] == 1


def _expired_session_with_edited_work(
    monkeypatch, tmp_path: Path, capsys, *, lang: str = "java"
) -> tuple[Path, int]:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    assert main(["start", "bank_system", lang, "--reset", "--no-console"]) == 0
    capsys.readouterr()
    if lang == "java":
        work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
        work.write_text(
            work.read_text(encoding="utf-8").replace(
                "return false;", "return false; // keep-me", 1
            ),
            encoding="utf-8",
        )
    else:
        work = tmp_path / "work" / "bank_system" / lang / "work.py"
        work.write_text(work.read_text(encoding="utf-8") + "# keep-me\n", encoding="utf-8")
    session = load_session()
    assert session is not None
    session["unlocked"] = 2
    session["started_at"] = 1_700_000_000
    session_file.write_text(json.dumps(session, indent=2) + "\n", encoding="utf-8")
    now = 1_700_000_000 + 90 * 60 + 5
    monkeypatch.setattr("honepad.session.time.time", lambda: now)
    return work, now


@pytest.mark.parametrize("argv", (["console"], ["vscode", "--no-open"], []))
def test_resume_restarts_dead_clock_keeps_work(
    monkeypatch, tmp_path: Path, capsys, argv: list[str]
) -> None:
    work, now = _expired_session_with_edited_work(monkeypatch, tmp_path, capsys)
    if argv != ["vscode", "--no-open"]:
        monkeypatch.setattr(sys, "stdin", io.StringIO("q\n"))
    assert main(argv) == 0
    out = capsys.readouterr().out
    after = load_session()
    assert after is not None
    assert after["unlocked"] == 2
    assert after["started_at"] == now
    assert remaining_s(int(after["started_at"]), int(after["minutes"]), now) == 5400
    assert "keep-me" in work.read_text(encoding="utf-8")
    assert "NOTE: previous clock was 0. New clock started. Work file kept." in out
    assert "clock_restarted" not in after
    if argv != ["vscode", "--no-open"]:
        assert "remaining_s=5400" in out
        assert "TIME UP" not in out


def test_start_writes_spec_beside_work(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    spec = tmp_path / "work" / "bank_system" / "java" / "spec.md"
    assert spec.is_file()
    text = spec.read_text(encoding="utf-8")
    assert "create_account" in text
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert "top_spenders" in spec.read_text(encoding="utf-8")


def test_bare_honepad_no_session_prints_next(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    assert main([]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "NEXT:" in out
    assert "honepad start" in out
    assert "bank_system" in out


def test_bare_honepad_next_uses_argv0(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    monkeypatch.setattr(sys, "argv", ["./honepad"])
    assert main([]) == 1
    out = capsys.readouterr().out
    assert "NEXT: ./honepad start bank_system java" in out


def test_bare_honepad_next_uses_module_form(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    monkeypatch.setattr(sys, "argv", [str(Path("src") / "honepad" / "__main__.py")])
    assert main([]) == 1
    out = capsys.readouterr().out
    exe = Path(sys.executable).name or "python3"
    assert f"NEXT: {exe} -m honepad start bank_system java" in out


def test_start_without_args_prints_next(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "NEXT:" in out
    assert "bank_system" in out


def test_run_level_zero_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    code = main(["run", "bank_system", "--lang", "python3", "--level", "0", "--kind", "solution"])
    assert code == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "1.." in out
    assert "\nOK\n" not in out
    assert not out.strip().endswith("OK")
    assert "UNLOCKED" not in out


def test_load_session_rejects_path_escape_problem(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "../../pwn",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    escaped = (tmp_path / "work" / "../../pwn").resolve()
    sibling = tmp_path.parent / "pwn"
    assert main(["console"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert not escaped.exists()
    assert not sibling.exists()
    assert not (tmp_path / "work").exists()
    with pytest.raises(ValueError, match="problem"):
        load_session()


def test_load_session_rejects_unknown_lang(monkeypatch, tmp_path: Path) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "not-a-lang",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    with pytest.raises((ValueError, KeyError), match="lang|language"):
        load_session()


def _write_python_lang_session(tmp_path: Path) -> Path:
    session_file = tmp_path / "session.json"
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    return session_file


def test_default_unknown_lang_python_suggests_python3(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(_write_python_lang_session(tmp_path)))
    code = main([])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "unknown language: python" in out
    assert "FAIL: 'unknown language" not in out
    assert "python3" in out
    assert "NEXT:" in out
    assert "langs" in out
    assert "Traceback" not in out


def test_timer_unknown_lang_python_suggests_python3(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(_write_python_lang_session(tmp_path)))
    code = main(["timer"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "unknown language: python" in out
    assert "FAIL: 'unknown language" not in out
    assert "python3" in out
    assert "NEXT:" in out
    assert "langs" in out
    assert "Traceback" not in out


def test_load_session_rejects_unknown_problem(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "not-a-problem",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    assert main(["console"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "invalid problem" in out
    assert "not-a-problem" in out
    with pytest.raises(ValueError, match="problem"):
        load_session()


def test_load_session_inf_started_at_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        '{"problem": "bank_system", "lang": "python3",'
        ' "started_at": 1e309, "minutes": 90, "unlocked": 1}\n',
        encoding="utf-8",
    )
    code = main(["timer"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "Traceback" not in out
    with pytest.raises(ValueError):
        load_session()


def test_load_session_rejects_unlocked_past_max(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 90,
                "unlocked": 99,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    code = main(["console"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "Traceback" not in out
    with pytest.raises(ValueError, match="unlocked"):
        load_session()


def test_load_session_rejects_minutes_zero(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session_file.write_text(
        json.dumps(
            {
                "problem": "bank_system",
                "lang": "python3",
                "started_at": 1_700_000_000,
                "minutes": 0,
                "unlocked": 1,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    code = main(["timer"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "Traceback" not in out
    with pytest.raises(ValueError, match="minutes"):
        load_session()


def test_start_minutes_zero_does_not_write_session(monkeypatch, tmp_path: Path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    code = main(["start", "bank_system", "python3", "--minutes", "0", "--no-console"])
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL" in out
    assert "minutes" in out
    assert "Traceback" not in out
    assert not session_file.is_file()


def test_start_minutes_on_resume_updates_running_clock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    clock = {"now": 1_700_000_000}

    def _now() -> float:
        return float(clock["now"])

    monkeypatch.setattr("honepad.session.time.time", _now)
    assert (
        main(["start", "bank_system", "python3", "--minutes", "90", "--reset", "--no-console"]) == 0
    )
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(work.read_text(encoding="utf-8") + "# keep-me\n", encoding="utf-8")
    session = load_session()
    assert session is not None
    session["unlocked"] = 2
    save_session(session)
    clock["now"] = 1_700_000_000 + 60
    assert main(["start", "bank_system", "python3", "--minutes", "30", "--no-console"]) == 0
    out = capsys.readouterr().out
    after = load_session()
    assert after is not None
    assert after["minutes"] == 30
    assert after["started_at"] == 1_700_000_000
    assert after["unlocked"] == 2
    assert remaining_s(int(after["started_at"]), int(after["minutes"]), int(clock["now"])) == 1740
    assert "NOTE:" in out
    assert "clock is now 30" in out
    assert "# keep-me" in work.read_text(encoding="utf-8")


def test_start_without_minutes_keeps_saved_duration(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert (
        main(["start", "bank_system", "python3", "--minutes", "30", "--reset", "--no-console"]) == 0
    )
    first = load_session()
    assert first is not None
    assert first["minutes"] == 30
    capsys.readouterr()
    assert main(["start", "bank_system", "python3", "--no-console"]) == 0
    after = load_session()
    assert after is not None
    assert after["minutes"] == 30
    assert after["started_at"] == first["started_at"]


@pytest.mark.parametrize(
    "argv",
    (["console", "--minutes", "30"], ["vscode", "--minutes", "30", "--no-open"]),
)
def test_resume_current_session_honors_minutes(
    monkeypatch, tmp_path: Path, capsys, argv: list[str]
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert (
        main(["start", "bank_system", "python3", "--minutes", "90", "--reset", "--no-console"]) == 0
    )
    first = load_session()
    assert first is not None
    assert first["minutes"] == 90
    capsys.readouterr()
    if argv[0] == "console":
        monkeypatch.setattr(sys, "stdin", io.StringIO("q\n"))
    assert main(argv) == 0
    out = capsys.readouterr().out
    after = load_session()
    assert after is not None
    assert after["minutes"] == 30
    assert "NOTE:" in out
    assert "clock is now 30" in out


def test_save_session_drops_unknown_keys(monkeypatch, tmp_path: Path) -> None:
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
                "evil": "/etc/passwd",
                "clock_restarted": True,
            }
        )
        + "\n",
        encoding="utf-8",
    )
    session = load_session()
    assert session is not None
    assert "evil" not in session
    assert "clock_restarted" not in session
    save_session(session)
    written = json.loads(session_file.read_text(encoding="utf-8"))
    assert "evil" not in written
    assert "clock_restarted" not in written
    assert set(written) == {"problem", "lang", "started_at", "minutes", "unlocked"}


def test_reset_refuses_work_symlink(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    solution = repo_root() / "langs" / "python3" / "problems" / "bank_system" / "solution.py"
    original = solution.read_text(encoding="utf-8")
    work.unlink()
    work.symlink_to(solution)
    try:
        code = main(["start", "bank_system", "python3", "--reset", "--no-console"])
        captured = capsys.readouterr()
        out = captured.out + captured.err
        assert code == 1
        assert "FAIL" in out
        assert "Traceback" not in out
        assert solution.read_text(encoding="utf-8") == original
        assert work.is_symlink()
    finally:
        if solution.read_text(encoding="utf-8") != original:
            solution.write_text(original, encoding="utf-8")


def test_reset_breaks_work_hardlink_to_pack(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    solution = repo_root() / "langs" / "python3" / "problems" / "bank_system" / "solution.py"
    original = solution.read_text(encoding="utf-8")
    work.unlink()
    os.link(solution, work)
    try:
        code = main(["start", "bank_system", "python3", "--reset", "--no-console"])
        captured = capsys.readouterr()
        out = captured.out + captured.err
        assert code == 0
        assert "Traceback" not in out
        assert solution.read_text(encoding="utf-8") == original
        assert work.is_file()
        assert not work.is_symlink()
        assert work.stat().st_ino != solution.stat().st_ino
        assert work.read_text(encoding="utf-8")
    finally:
        if solution.read_text(encoding="utf-8") != original:
            solution.write_text(original, encoding="utf-8")


def test_write_work_spec_breaks_hardlink_to_pack(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    spec = tmp_path / "work" / "bank_system" / "python3" / "spec.md"
    stub = repo_root() / "langs" / "python3" / "problems" / "bank_system" / "stub.py"
    original = stub.read_text(encoding="utf-8")
    spec.unlink()
    os.link(stub, spec)
    try:
        assert spec.stat().st_ino == stub.stat().st_ino
        code = main(["start", "bank_system", "python3", "--no-console"])
        captured = capsys.readouterr()
        out = captured.out + captured.err
        assert code == 0
        assert "Traceback" not in out
        assert stub.read_text(encoding="utf-8") == original
        assert spec.is_file()
        assert not spec.is_symlink()
        assert spec.stat().st_ino != stub.stat().st_ino
        text = spec.read_text(encoding="utf-8")
        assert "create_account" in text
        assert text != original
    finally:
        if stub.read_text(encoding="utf-8") != original:
            stub.write_text(original, encoding="utf-8")


def test_loop_console_bad_json_keeps_last_session(monkeypatch, tmp_path: Path) -> None:
    from honepad.console import loop_console

    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))
    session = {
        "problem": "bank_system",
        "lang": "python3",
        "started_at": 1_700_000_000,
        "minutes": 90,
        "unlocked": 1,
    }
    session_file.write_text(json.dumps(session) + "\n", encoding="utf-8")

    class CorruptThenQuit(io.StringIO):
        def readline(self, *args: object, **kwargs: object) -> str:
            session_file.write_text("{not-json\n", encoding="utf-8")
            return super().readline(*args, **kwargs)

    stdout = io.StringIO()
    code = loop_console(
        session,
        stdin=CorruptThenQuit("\nq\n"),
        stdout=stdout,
        live=False,
    )
    out = stdout.getvalue()
    assert code == 0
    assert "OK: quit" in out
    assert "FAIL:" in out
    assert session_file.name in out or "session" in out
    assert session["problem"] == "bank_system"
    assert session["lang"] == "python3"
    assert session["unlocked"] == 1
    assert "Traceback" not in out


def _later_method_tokens(problem: str, lang: str) -> list[str]:
    naming = naming_for(lang)
    unlocked = methods_through_level(problem, 1, naming)
    later = methods_through_level(problem, 4, naming) - unlocked
    tokens: list[str] = []
    for name in later:
        tokens.append(name)
        if "_" in name:
            parts = name.split("_")
            tokens.append(parts[0] + "".join(part.title() for part in parts[1:]))
        else:
            snake = []
            for i, ch in enumerate(name):
                if ch.isupper() and i:
                    snake.append("_")
                snake.append(ch.lower())
            tokens.append("".join(snake))
    return sorted(set(tokens))


@pytest.mark.parametrize("lang", sorted(_RUNNERS))
def test_start_work_hides_later_level_methods(
    monkeypatch, tmp_path: Path, capsys, lang: str
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", lang, "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = work_src("bank_system", lang)
    text = work.read_text(encoding="utf-8")
    later = _later_method_tokens("bank_system", lang)
    leaked = [token for token in later if token in text]
    assert leaked == [], f"{lang} work still lists {leaked}"
    l1 = methods_through_level("bank_system", 1, naming_for(lang))
    assert l1
    if lang in {"java", "python3", "javascript", "typescript", "ruby"}:
        assert any(name in text for name in l1)


def test_pack_stubs_keep_later_methods() -> None:
    kept = 0
    for lang in sorted(_RUNNERS):
        ext = str(language(lang)["ext"])
        stub = repo_root() / "langs" / lang / "problems" / "bank_system" / f"stub.{ext}"
        text = stub.read_text(encoding="utf-8")
        later = _later_method_tokens("bank_system", lang)
        if any(token in text for token in later):
            kept += 1
    assert kept >= 20


def test_unlock_appends_ruby_and_comment_lang(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "ruby", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    ruby = tmp_path / "work" / "bank_system" / "ruby" / "work.rb"
    ruby.write_text(
        ruby.read_text(encoding="utf-8").replace("not implemented", "keep-me", 1),
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    after = ruby.read_text(encoding="utf-8")
    assert "keep-me" in after
    assert "def top_spenders(" in after
    assert "def merge_accounts(" not in after
    assert main(["start", "bank_system", "csharp", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    cs = tmp_path / "work" / "bank_system" / "csharp" / "work.cs"
    cs.write_text(
        cs.read_text(encoding="utf-8").replace(
            "public class Simulation", "public class Simulation // keep-me"
        ),
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    cs_after = cs.read_text(encoding="utf-8")
    assert "keep-me" in cs_after
    assert "top_spenders(" in cs_after
    assert "merge_accounts(" not in cs_after
    assert class_name_for("bank_system") in cs_after


def test_submit_current_level_unlocks(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution", "--level", "1"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_submit_confirm_n_cancels(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution", "--confirm", "n"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert "cancelled" in out.lower()
    assert load_session()["unlocked"] == 1


def test_submit_confirm_y_unlocks(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    src = repo_root() / "langs" / "python3" / "problems" / "bank_system" / "solution.py"
    work.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution", "--confirm", "y"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_submit_other_level_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution", "--level", "4"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert "through LEVEL 4" in out


def test_kind_stub_still_fails_when_work_is_solution(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    src = (
        Path(__file__).resolve().parents[1]
        / "langs"
        / "python3"
        / "problems"
        / "bank_system"
        / "solution.py"
    )
    work.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    assert main(["run", "bank_system", "--kind", "stub"]) == 1
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert "FAIL" in out
    assert load_session()["unlocked"] == 1


def test_submit_broken_js_work_prints_fail_not_traceback(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    work.write_text("class Simulation\n", encoding="utf-8")
    code = main(["submit", "bank_system", "--kind", "solution"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL:" in out
    assert "Traceback" not in out
    assert load_session()["unlocked"] == 1
    assert work.read_text(encoding="utf-8") == "class Simulation\n"


def test_expired_submit_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
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
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=0" in out
    assert "UNLOCKED" not in out
    assert "TIME UP" in out
    assert load_session()["unlocked"] == 1


def test_submit_does_not_unlock_when_clock_expires_during_run(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    clock = {"now": 1_700_000_000}

    def _now() -> float:
        return float(clock["now"])

    monkeypatch.setattr("honepad.session.time.time", _now)
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    started = int(load_session()["started_at"])
    clock["now"] = started + 89 * 60
    real_run = __import__("honepad.cli", fromlist=["run"]).run

    def _run_then_expire(*args: object, **kwargs: object):
        clock["now"] = started + 91 * 60
        return real_run(*args, **kwargs)

    monkeypatch.setattr("honepad.cli.run", _run_then_expire)
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert "TIME UP" in out
    assert load_session()["unlocked"] == 1


def test_submit_without_class_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("notes\n", encoding="utf-8")
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL:" in out
    assert not any(line.strip() == "OK" for line in out.splitlines())
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert work.read_text(encoding="utf-8") == "notes\n"
    spec = work.parent / "spec.md"
    assert spec.is_file()
    assert "top_spenders" not in spec.read_text(encoding="utf-8")


def test_submit_class_name_in_comment_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("# Simulation notes\n", encoding="utf-8")
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL:" in out
    assert "Simulation" in out
    assert "UNLOCKED" not in out
    assert "start --reset" in out
    assert load_session()["unlocked"] == 1
    assert work.read_text(encoding="utf-8") == "# Simulation notes\n"
    assert "def " not in work.read_text(encoding="utf-8")


def test_submit_comment_method_name_still_merges_java(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    text = work.read_text(encoding="utf-8")
    assert "topSpenders" not in text
    work.write_text(
        text.replace(
            "public class Simulation {",
            "public class Simulation {\n    // topSpenders(\n",
        ),
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    after = work.read_text(encoding="utf-8")
    assert "public List<String> topSpenders" in after


def test_submit_comment_method_name_still_merges_python(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    text = work.read_text(encoding="utf-8")
    assert "def top_spenders(self" not in text
    work.write_text(
        text.replace(
            "class Simulation:",
            "class Simulation:\n    # def top_spenders(\n",
        ),
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    after = work.read_text(encoding="utf-8")
    assert "def top_spenders(self" in after


def test_python_syntax_error_includes_line_or_token(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(
        "class Simulation:\n"
        "    def create_account(self, timestamp, account_id):\n"
        "        return ???\n",
        encoding="utf-8",
    )
    assert main(["run", "bank_system"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "SyntaxError" in out
    assert "line 3" in out or "???" in out
    next_lines = [line for line in out.splitlines() if "NEXT:" in line]
    assert next_lines
    assert any("start --reset" in line or "work" in line for line in next_lines)


def test_work_exists_without_class_is_not_missing(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest = work_src("bank_system", "python3")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("notes\n", encoding="utf-8")
    with pytest.raises(ValueError) as excinfo:
        ensure_work_copy("bank_system", "python3", reset=False, level=2, require_merge=True)
    text = str(excinfo.value)
    assert "work file missing" not in text
    assert "Simulation" in text
    assert "start --reset" in text


def test_require_merge_rejects_class_name_in_comment(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    dest = work_src("bank_system", "python3")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("# Simulation notes\n", encoding="utf-8")
    with pytest.raises(ValueError) as excinfo:
        ensure_work_copy("bank_system", "python3", reset=False, level=2, require_merge=True)
    text = str(excinfo.value)
    assert "work file missing" not in text
    assert "Simulation" in text
    assert "start --reset" in text
    assert dest.read_text(encoding="utf-8") == "# Simulation notes\n"


def test_merge_fail_prints_next_reset(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("notes\n", encoding="utf-8")
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL:" in out
    assert "work file missing" not in out
    assert "Simulation" in out
    assert "start --reset" in out
    next_lines = [line for line in out.splitlines() if "NEXT:" in line]
    assert next_lines
    assert any("start --reset" in line or "work" in line for line in next_lines)
    assert load_session()["unlocked"] == 1


def _l1_python_work(create_ok: object, create_dup: object, missing: object) -> str:
    return (
        "class Simulation:\n"
        "    def __init__(self):\n"
        "        self.accounts = {}\n"
        "\n"
        "    def create_account(self, timestamp, account_id):\n"
        "        if account_id in self.accounts:\n"
        f"            return {create_dup!r}\n"
        "        self.accounts[account_id] = 0\n"
        f"        return {create_ok!r}\n"
        "\n"
        "    def deposit(self, timestamp, account_id, amount):\n"
        "        if account_id not in self.accounts:\n"
        f"            return {missing!r}\n"
        "        self.accounts[account_id] += amount\n"
        "        return self.accounts[account_id]\n"
        "\n"
        "    def transfer(self, timestamp, source_account_id, target_account_id, amount):\n"
        "        if source_account_id not in self.accounts:\n"
        f"            return {missing!r}\n"
        "        if target_account_id not in self.accounts:\n"
        f"            return {missing!r}\n"
        "        if source_account_id == target_account_id:\n"
        f"            return {missing!r}\n"
        "        if self.accounts[source_account_id] < amount:\n"
        f"            return {missing!r}\n"
        "        self.accounts[source_account_id] -= amount\n"
        "        self.accounts[target_account_id] += amount\n"
        "        return self.accounts[source_account_id]\n"
    )


def test_python_int_one_is_not_true(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(_l1_python_work(1, 0, None), encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    out = capsys.readouterr().out
    assert "FAIL" in out
    assert "True" in out
    assert "actual=1" in out
    assert "UNLOCKED" not in out


def test_python_true_still_passes(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(_l1_python_work(True, False, None), encoding="utf-8")
    assert main(["run", "bank_system"]) == 0
    out = capsys.readouterr().out
    assert "FAIL" not in out
    assert "OK" in out


def test_python_zero_is_not_none(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(_l1_python_work(True, False, 0), encoding="utf-8")
    assert main(["run", "bank_system"]) == 1
    out = capsys.readouterr().out
    assert "FAIL" in out
    assert "None" in out
    assert "actual=0" in out


def test_python_none_still_passes(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(_l1_python_work(True, False, None), encoding="utf-8")
    assert main(["run", "bank_system"]) == 0
    out = capsys.readouterr().out
    assert "FAIL" not in out
    assert "OK" in out


def test_submit_rejects_fake_adapter_passed_json(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(
        "class Simulation:\n"
        "    def __init__(self):\n"
        '        print(\'{"passed": 99, "failed": []}\')\n'
        "        raise SystemExit(0)\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1


def _exact_l1_pass_json() -> str:
    from honepad.traces import load_cases

    n = len(load_cases("bank_system", 1))
    return json.dumps({"passed": n, "failed": []})


def test_submit_rejects_exact_count_fake_json_systemexit(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(
        f"print({_exact_l1_pass_json()!r})\nraise SystemExit(0)\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "OK" not in out
    assert "UNLOCKED" not in out
    assert "no Simulation class" not in out
    assert "passed=" not in out
    assert load_session()["unlocked"] == 1


def test_submit_rejects_exact_count_fake_json_os_exit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(
        f"import os\nprint({_exact_l1_pass_json()!r}, flush=True)\nos._exit(0)\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "OK" not in out
    assert "UNLOCKED" not in out
    assert "no Simulation class" not in out
    assert "passed=" not in out
    assert load_session()["unlocked"] == 1


def test_run_systemexit_at_import_prints_path_and_next(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("raise SystemExit(0)\n", encoding="utf-8")
    code = main(["run", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL:" in out
    assert "SystemExit" in out
    assert "work.py" in out
    assert "FAIL: 0" not in out
    next_lines = [line for line in out.splitlines() if "NEXT:" in line]
    assert next_lines
    assert any("start --reset" in line for line in next_lines)


def test_submit_rejects_fake_json_on_dunder_stdout_os_exit(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    payload = _exact_l1_pass_json()
    work.write_text(
        f"import os, sys\nprint({payload!r}, file=sys.__stdout__, flush=True)\nos._exit(0)\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "OK" not in out
    assert "UNLOCKED" not in out
    assert "no Simulation class" not in out
    assert "passed=" not in out
    assert load_session()["unlocked"] == 1


def test_submit_rejects_fake_json_on_fd1_os_exit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    payload = _exact_l1_pass_json()
    work.write_text(
        f"import os\nos.write(1, {payload.encode()!r} + b'\\n')\nos._exit(0)\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "OK" not in out
    assert "UNLOCKED" not in out
    assert "no Simulation class" not in out
    assert "passed=" not in out
    assert load_session()["unlocked"] == 1


def test_submit_class_keyword_in_comment_does_not_unlock(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("# class Simulation notes\n", encoding="utf-8")
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL:" in out
    assert "Simulation" in out
    assert "UNLOCKED" not in out
    assert "start --reset" in out
    assert load_session()["unlocked"] == 1
    assert work.read_text(encoding="utf-8") == "# class Simulation notes\n"
    assert "def " not in work.read_text(encoding="utf-8")


def test_submit_js_class_comment_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    work.write_text("// class Simulation\n", encoding="utf-8")
    code = main(["submit", "bank_system", "--kind", "solution"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL:" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert work.read_text(encoding="utf-8") == "// class Simulation\n"


def test_declares_class_skips_comments_and_accepts_js_const() -> None:
    name = "Simulation"
    assert not declares_class("# class Simulation notes\n", "py", name)
    assert not declares_class("// class Simulation\n", "js", name)
    assert not declares_class("print('class Simulation')\n", "py", name)
    assert declares_class("class Simulation:\n    pass\n", "py", name)
    assert declares_class("public class Simulation {\n}\n", "java", name)
    assert declares_class("export class Simulation {\n}\n", "js", name)
    assert declares_class("const Simulation = class {\n};\n", "js", name)
    assert declares_class("let Simulation = class {\n};\n", "js", name)
    assert declares_class("var Simulation = class {\n};\n", "js", name)
    assert declares_class("module.exports = {\n  Simulation: class {}\n};\n", "js", name)


def test_submit_js_const_class_unlocks(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    work.write_text(
        "const Simulation = class {\n  constructor() {}\n};\nmodule.exports = { Simulation };\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 0
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_submit_rejects_atexit_fake_json_os_exit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    payload = _exact_l1_pass_json()
    work.write_text(
        "import atexit, os\n"
        f"atexit.register(lambda: (os.write(1, {payload.encode()!r} + b'\\n'), os._exit(0)))\n"
        "class Simulation:\n    pass\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1


def test_declares_class_skips_block_comments_and_docstrings() -> None:
    name = "Simulation"
    assert not declares_class("/*\nclass Simulation {\n}\n*/\n", "js", name)
    assert not declares_class('"""\nclass Simulation:\n    pass\n"""\n', "py", name)
    assert declares_class("class Simulation:\n    pass\n", "py", name)


def test_submit_block_comment_class_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    work.write_text("/*\nclass Simulation {\n}\n*/\n", encoding="utf-8")
    code = main(["submit", "bank_system", "--kind", "solution"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL:" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert work.read_text(encoding="utf-8") == "/*\nclass Simulation {\n}\n*/\n"


def test_submit_rejects_patched_os_exit_fake_json(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    payload = _exact_l1_pass_json()
    work.write_text(
        "import os\n"
        f"os._exit = lambda _rc: os.write(1, {payload.encode()!r} + b'\\n')\n"
        "class Simulation:\n    pass\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1


def test_submit_rejects_fake_json_on_fd3_os_exit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    payload = _exact_l1_pass_json()
    work.write_text(
        f"import os\nos.write(3, {payload.encode()!r} + b'\\n')\nos._exit(0)\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "OK" not in out
    assert "UNLOCKED" not in out
    assert "passed=" not in out
    assert load_session()["unlocked"] == 1


def test_submit_rejects_import_time_values_differ_patch(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(
        "import honepad.runner\n"
        "honepad.runner._values_differ = lambda *a, **k: False\n"
        "class Simulation:\n"
        "    def __getattr__(self, name):\n"
        "        return lambda *a, **k: None\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "FAIL" in out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1


def test_java_unlock_merge_targets_simulation_not_last_brace(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    work.write_text(
        "public class Simulation {\n"
        "  public Simulation() {}\n"
        "  public Boolean createAccount(long t, String id) { return true; }\n"
        "}\n"
        "class Account {\n  Account() {}\n}\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 0
    assert "UNLOCKED" in out
    body = work.read_text(encoding="utf-8")
    simulation, _sep, account = body.partition("class Account")
    assert "topSpenders" in simulation
    assert "topSpenders" not in account
    assert "class Account" in body


def test_java_unlock_merge_ignores_brace_in_string() -> None:
    work = """public class Simulation {
  private final String note = "{";
  public Simulation() {}
  public Boolean createAccount(long t, String id) { return true; }
  public Integer deposit(long t, String id, int amount) { return 0; }
  public Integer transfer(long t, String a, String b, int amount) { return 0; }
}
"""
    full = (repo_root() / "langs/java/problems/bank_system/stub.java").read_text(encoding="utf-8")
    allowed = methods_through_level("bank_system", 2, naming_for("java"))
    merged = merge_unlocked_methods(work, full, "java", allowed, "Simulation")
    assert 'note = "{"' in merged
    assert "topSpenders" in merged


def test_js_unlock_merge_ignores_brace_in_string() -> None:
    work = """class Simulation {
  const note = "{";
  constructor() {}
  createAccount(t, id) { return true; }
  deposit(t, id, amount) { return 0; }
  transfer(t, a, b, amount) { return 0; }
}
"""
    full = (repo_root() / "langs/javascript/problems/bank_system/stub.js").read_text(
        encoding="utf-8"
    )
    allowed = methods_through_level("bank_system", 2, naming_for("javascript"))
    merged = merge_unlocked_methods(work, full, "js", allowed, "Simulation")
    assert 'note = "{"' in merged
    assert "topSpenders" in merged


def test_js_unlock_merge_inserts_method_when_call_exists() -> None:
    work = """class Simulation {
  constructor() {}
  createAccount(t, id) { return true; }
  deposit(t, id, amount) { this.topSpenders(t, 1); return 0; }
  transfer(t, a, b, amount) { return 0; }
}
"""
    full = (repo_root() / "langs/javascript/problems/bank_system/stub.js").read_text(
        encoding="utf-8"
    )
    allowed = methods_through_level("bank_system", 2, naming_for("javascript"))
    merged = merge_unlocked_methods(work, full, "js", allowed, "Simulation")
    assert "this.topSpenders(t, 1)" in merged
    decls = [
        line.strip()
        for line in merged.splitlines()
        if line.strip().startswith("topSpenders(") and "{" in line
    ]
    assert decls
    assert "not implemented" in decls[0]


def test_java_unlock_merge_inserts_method_when_call_exists() -> None:
    work = """public class Simulation {
  public Simulation() {}
  public Boolean createAccount(long t, String id) { return true; }
  public Integer deposit(long t, String id, int amount) { this.topSpenders(t, 1); return 0; }
  public Integer transfer(long t, String a, String b, int amount) { return 0; }
}
"""
    full = (repo_root() / "langs/java/problems/bank_system/stub.java").read_text(encoding="utf-8")
    allowed = methods_through_level("bank_system", 2, naming_for("java"))
    merged = merge_unlocked_methods(work, full, "java", allowed, "Simulation")
    assert "this.topSpenders(t, 1)" in merged
    assert "public List<String> topSpenders" in merged


def test_js_unlock_merge_ignores_brace_in_template() -> None:
    work = """class Simulation {
  constructor() {
    this.note = `}`;
  }
  createAccount(t, id) { this.keep = `keep {`; return true; }
  deposit(t, id, amount) { return 0; }
  transfer(t, a, b, amount) { return 0; }
}
"""
    full = (repo_root() / "langs/javascript/problems/bank_system/stub.js").read_text(
        encoding="utf-8"
    )
    allowed = methods_through_level("bank_system", 2, naming_for("javascript"))
    merged = merge_unlocked_methods(work, full, "js", allowed, "Simulation")
    assert "this.note = `}`" in merged
    assert "this.keep = `keep {`" in merged
    assert "topSpenders" in merged
    ctor = merged[merged.find("constructor") : merged.find("createAccount")]
    assert "topSpenders" not in ctor


def test_java_unlock_merge_ignores_brace_in_line_comment() -> None:
    work = """public class Simulation {
  // keep {
  public Simulation() {}
  public Boolean createAccount(long t, String id) { return true; }
  public Integer deposit(long t, String id, int amount) { return 0; }
  public Integer transfer(long t, String a, String b, int amount) { return 0; }
}
"""
    full = (repo_root() / "langs/java/problems/bank_system/stub.java").read_text(encoding="utf-8")
    allowed = methods_through_level("bank_system", 2, naming_for("java"))
    merged = merge_unlocked_methods(work, full, "java", allowed, "Simulation")
    assert "// keep {" in merged
    assert "topSpenders" in merged


def test_python_unlock_merge_targets_simulation_not_last_class(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text(
        "class Simulation:\n"
        "    def create_account(self, *args):\n        return True\n"
        "    def deposit(self, *args):\n        return 0\n"
        "    def transfer(self, *args):\n        return 0\n"
        "\nclass Account:\n    pass\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 0
    assert "UNLOCKED" in out
    body = work.read_text(encoding="utf-8")
    simulation, _sep, account = body.partition("class Account")
    assert "def top_spenders" in simulation
    assert "def top_spenders" not in account


def test_ruby_unlock_merge_targets_simulation_not_last_end(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "ruby", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "ruby" / "work.rb"
    work.write_text(
        "class Simulation\n"
        "  def create_account(*); end\n"
        "  def deposit(*); end\n"
        "  def transfer(*); end\n"
        "end\n"
        "class Account\n  def initialize; end\nend\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 0
    assert "UNLOCKED" in out
    body = work.read_text(encoding="utf-8")
    simulation, _sep, account = body.partition("class Account")
    assert "def top_spenders" in simulation
    assert "def top_spenders" not in account


def test_js_unlock_merge_targets_simulation_not_first_class(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "javascript", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "javascript" / "work.js"
    work.write_text(
        "class Account {\n  constructor() {}\n}\n"
        "class Simulation {\n  constructor() {}\n"
        "  createAccount() {}\n  deposit() {}\n  transfer() {}\n}\n"
        "module.exports = { Simulation };\n",
        encoding="utf-8",
    )
    code = main(["submit", "bank_system", "--kind", "solution"])
    out = capsys.readouterr().out
    assert code == 0
    assert "UNLOCKED" in out
    body = work.read_text(encoding="utf-8")
    account, _sep, simulation = body.partition("class Simulation")
    assert "topSpenders" in simulation
    assert "topSpenders" not in account


def test_declares_class_skips_unclosed_block_comment() -> None:
    name = "Simulation"
    assert not declares_class("/*\nclass Simulation {\n}\n", "js", name)
    assert not declares_class('"""\nclass Simulation:\n    pass\n', "py", name)
    assert declares_class("class Simulation:\n    pass\n", "py", name)
