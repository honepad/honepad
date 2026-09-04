import io
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.console import _confirm_unlock, _read_choice, dispatch, loop_console, render_banner
from honepad.javatest import java_ident
from honepad.pythontest import pytest_ident
from honepad.session import ensure_work_copy, load_session, save_session
from honepad.term import (
    color_enabled,
    columns,
    file_link,
    file_uri,
    firework_frame,
    format_clock,
    home_short,
    level_dots,
    meter,
    paint_spec,
    play_firework,
    print_complete,
    render_fail,
    render_help,
    render_menu,
    render_pass,
    render_prompt,
    spec_line,
    term_width,
)
from honepad.traces import load_cases
from honepad.workspace import _link_or_copy, open_vscode, write_workspace


def test_format_clock_pads_minutes() -> None:
    assert format_clock(0) == "00:00"
    assert format_clock(65) == "01:05"
    assert format_clock(3600) == "1:00:00"


def test_file_link_uses_osc8() -> None:
    path = Path("/tmp/honepad-work.java")
    text = file_link(path)
    assert "\x1b]8;;file://" in text
    assert "honepad-work.java" in text
    assert file_uri(path).startswith("file://")


def test_start_work_path_is_file_uri(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    out = capsys.readouterr().out
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    assert "WORK:" in out
    assert str(work) in out
    assert "file://" in out
    assert "honepad console" in out


def test_banner_time_up_when_remaining_zero() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 1,
    }
    text = render_banner(session, now=100 + 90 * 60 + 1)
    assert "TIME UP" in text
    assert "will not unlock" in text.lower()
    assert "quit then start" in text.lower()
    assert "keeps work" in text.lower()


def test_banner_done_at_last_level_even_when_clock_is_zero() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 4,
        "cleared": True,
    }
    text = render_banner(session, now=100 + 90 * 60 + 1)
    assert "DONE: bank_system java" in text
    assert "2 replay" in text
    assert "TIME UP" not in text
    assert "will not unlock" not in text.lower()
    assert "LEVEL 4" in text


def test_banner_last_level_without_cleared_is_not_done() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 4,
    }
    text = render_banner(session, now=100 + 90 * 60 + 1)
    assert "DONE:" not in text
    assert "2 replay" not in text
    assert "2 submit (local)" in text
    assert "last level" in text.lower()
    assert "TIME UP" not in text
    assert "LEVEL 4" in text


def test_loop_console_reprints_time_up_when_clock_hits_zero(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    session = {
        "problem": "bank_system",
        "lang": "python3",
        "started_at": 1_700_000_000,
        "minutes": 90,
        "unlocked": 1,
    }
    calls = {"n": 0}

    def fake_remaining(started_at: int, minutes: int, now: int | None = None) -> int:
        calls["n"] += 1
        return 60 if calls["n"] == 1 else 0

    monkeypatch.setattr("honepad.console.remaining_s", fake_remaining)
    stdout = io.StringIO()
    code = loop_console(
        dict(session),
        stdin=io.StringIO("\nq\n"),
        stdout=stdout,
        live=False,
    )
    out = stdout.getvalue()
    assert code == 0
    idx = out.find("TIME UP")
    assert idx != -1
    assert "remaining_s=60" in out[:idx]
    assert out.count("TIME UP") == 1
    assert "will not unlock" in out[idx:].lower()
    assert "will not unlock" not in out[:idx].lower()
    assert "Unlock?" not in out
    assert "OK: quit" in out


def test_loop_console_time_up_again_after_clock_restarts(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    session = {
        "problem": "bank_system",
        "lang": "python3",
        "started_at": 1_700_000_000,
        "minutes": 90,
        "unlocked": 1,
    }
    calls = {"n": 0}

    def fake_remaining(started_at: int, minutes: int, now: int | None = None) -> int:
        calls["n"] += 1
        n = calls["n"]
        if n <= 2:
            return 60
        if n <= 4:
            return 0
        if n <= 6:
            return 30
        return 0

    monkeypatch.setattr("honepad.console.remaining_s", fake_remaining)
    stdout = io.StringIO()
    code = loop_console(
        dict(session),
        stdin=io.StringIO("\n\n\nq\n"),
        stdout=stdout,
        live=False,
    )
    out = stdout.getvalue()
    assert code == 0
    assert out.count("TIME UP") == 2
    assert "OK: quit" in out


def test_loop_console_reset_all_reprints_banner_after_time_up(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    session = load_session()
    assert session is not None
    session["started_at"] = 1
    session["minutes"] = 1
    (tmp_path / "session.json").write_text(json.dumps(session, indent=2) + "\n", encoding="utf-8")
    session = load_session()
    assert session is not None
    stdout = io.StringIO()
    code = loop_console(
        dict(session),
        stdin=io.StringIO("3\nall\nq\n"),
        stdout=stdout,
        live=False,
    )
    out = stdout.getvalue()
    assert code == 0
    ok_idx = out.find("OK: LEVEL 1")
    assert ok_idx != -1
    assert "TIME UP" in out[:ok_idx]
    after = out[ok_idx:]
    last = after.rfind("remaining_s=")
    assert last != -1
    start = last + len("remaining_s=")
    digits = []
    for ch in after[start:]:
        if ch.isdigit():
            digits.append(ch)
        else:
            break
    assert digits
    assert int("".join(digits)) > 0
    assert out.rfind("TIME UP") < ok_idx
    assert "OK: quit" in out


def test_color_disabled_without_tty(monkeypatch) -> None:
    monkeypatch.delenv("FORCE_COLOR", raising=False)
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setattr(sys.stdout, "isatty", lambda: False)
    assert color_enabled() is False


def test_firework_launch_starts_low() -> None:
    rows = firework_frame(0)
    assert len(rows) == 11
    hits = [i for i, row in enumerate(rows) if "*" in row]
    assert hits
    assert hits[0] > len(rows) // 2


def test_firework_burst_spreads() -> None:
    rows = firework_frame(6)
    spark_rows = [row for row in rows if "*" in row or "+" in row]
    assert len(spark_rows) >= 4
    cols: list[int] = []
    for row in spark_rows:
        for i, ch in enumerate(row):
            if ch in "*+":
                cols.append(i)
    assert max(cols) - min(cols) >= 6


def test_play_firework_skips_without_color(monkeypatch, capsys) -> None:
    monkeypatch.delenv("FORCE_COLOR", raising=False)
    monkeypatch.setenv("NO_COLOR", "1")
    slept: list[float] = []
    monkeypatch.setattr("honepad.term.time.sleep", slept.append)
    play_firework()
    out = capsys.readouterr().out
    assert out == ""
    assert slept == []


def test_play_firework_redraws_when_color_forced(monkeypatch, capsys) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    slept: list[float] = []
    monkeypatch.setattr("honepad.term.time.sleep", slept.append)
    play_firework(frames=3, delay_s=0.04)
    out = capsys.readouterr().out
    assert "*" in out
    assert "\x1b[" in out
    assert "\x1b[11A" in out
    assert slept == [0.04, 0.04, 0.04]


def test_print_complete_plays_firework_when_color_forced(monkeypatch, capsys) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    monkeypatch.setattr("honepad.term.time.sleep", lambda _s: None)
    print_complete("bank_system", "java", levels=4, passed=19)
    out = capsys.readouterr().out
    assert "*" in out
    assert "\x1b[11A" in out
    done = out.find("DONE: bank_system java")
    assert done != -1
    assert out.find("*") < done
    assert "all 4 levels, 19 traces" in out
    assert "in_memory_database java" in out


def test_print_complete_rerun_skips_firework(monkeypatch, capsys) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    slept: list[float] = []
    monkeypatch.setattr("honepad.term.time.sleep", slept.append)
    print_complete("bank_system", "java", levels=4, passed=19, first=False)
    out = capsys.readouterr().out
    assert "OK: bank_system java still complete" in out
    assert "DONE:" not in out
    assert "*" not in out
    assert "\x1b[11A" not in out
    assert slept == []
    assert "all 4 levels, 19 traces" in out
    assert "in_memory_database java" in out


def test_print_complete_stays_plain_without_color(monkeypatch, capsys) -> None:
    monkeypatch.delenv("FORCE_COLOR", raising=False)
    monkeypatch.setenv("NO_COLOR", "1")
    slept: list[float] = []
    monkeypatch.setattr("honepad.term.time.sleep", slept.append)
    print_complete("bank_system", "java", levels=4, passed=19)
    out = capsys.readouterr().out
    assert out.startswith("DONE: bank_system java")
    assert "\x1b[11A" not in out
    assert slept == []


def test_no_color_wins_over_force(monkeypatch) -> None:
    monkeypatch.setenv("FORCE_COLOR", "1")
    monkeypatch.setenv("NO_COLOR", "1")
    assert color_enabled() is False


def test_banner_stays_plain_without_color(monkeypatch) -> None:
    monkeypatch.delenv("FORCE_COLOR", raising=False)
    monkeypatch.setenv("NO_COLOR", "1")
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 2,
    }
    text = render_banner(session, now=100)
    assert "\x1b[" not in text
    assert "honepad  bank_system  java  LEVEL 2" in text
    assert "unlocked=2" not in text


def test_banner_uses_bold_and_color_when_forced(monkeypatch) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    monkeypatch.setenv("COLORTERM", "truecolor")
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 2,
    }
    text = render_banner(session, now=100)
    assert "\x1b[1m" in text
    assert "\x1b[38;2;" in text
    assert "LEVEL 2" in text
    assert "honepad" in text


def test_menu_bolds_keys_when_forced(monkeypatch) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    text = render_menu("01:05")
    assert "\x1b[1m" in text
    assert "\x1b[1m1\x1b[0m" in text
    assert "run" in text
    assert "submit" in text
    assert "quit" in text


def test_menu_stays_plain_without_color(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    text = render_menu("01:05")
    assert "\x1b[" not in text
    assert text.startswith("[01:05] 1 run")


def test_menu_includes_level_without_color(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    text = render_menu("01:05", level=2)
    assert "\x1b[" not in text
    assert "LEVEL 2" in text
    assert "1 run" in text


def test_prompt_is_clock_and_level_only(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    text = render_prompt("01:05", level=2)
    assert text == "[01:05] LEVEL 2"
    assert "1 run" not in text
    assert "quit" not in text


def test_banner_shows_level_out_of_total(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    session = {
        "problem": "workers",
        "lang": "python3",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 2,
    }
    text = render_banner(session, now=100)
    assert "LEVEL 2/3" in text


def test_banner_dots_only_when_color_is_on(monkeypatch) -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 2,
    }
    monkeypatch.setenv("NO_COLOR", "1")
    assert "\u25cf" not in render_banner(session, now=100)
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    lit = render_banner(session, now=100)
    assert "\u25cf\u25cf" in lit
    assert "\u25cb\u25cb" in lit


def test_banner_keeps_remaining_s_for_agents(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 1,
    }
    assert "remaining_s=5400" in render_banner(session, now=100)


def test_banner_offers_help_key() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 1,
    }
    assert "? help" in render_banner(session)


def test_console_help_key_prints_every_key(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    monkeypatch.setenv("NO_COLOR", "1")
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("?\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "unlock the next level" in out
    assert "restarts at level 1" in out
    assert "NO_COLOR" in out
    assert "passed=" not in out
    assert "OK: quit" in out


def test_console_unknown_key_points_at_help(monkeypatch, tmp_path: Path) -> None:
    session = {
        "problem": "bank_system",
        "lang": "python3",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 1,
    }
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    stdout = io.StringIO()
    assert dispatch("z", session, stdout) == 1
    out = stdout.getvalue()
    assert "unknown option" in out
    assert "? prints what each key does" in out


def test_banner_includes_menu_keys() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 3,
    }
    text = render_banner(session, now=100)
    assert "1 run" in text
    assert "2 submit" in text
    assert "q quit" in text


def test_paint_spec_stays_plain_without_color(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    raw = "# Bank system level 3\n`pay` withdraws amount.\n"
    assert paint_spec(raw) == raw


def test_paint_spec_colors_heading_and_code_when_forced(monkeypatch) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    text = paint_spec("# Bank system level 3\n`pay` withdraws amount.\n")
    assert "\x1b[" in text
    assert "# Bank system level 3" in text
    assert "`pay`" in text
    heading, rest = text.split("\n", 1)
    assert heading.startswith("\x1b[")
    assert "\x1b[" in rest
    assert "withdraws amount." in rest


def test_start_paints_spec_heading_when_forced(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    out = capsys.readouterr().out
    assert "# Bank system level" in out
    heading = next(line for line in out.splitlines() if "# Bank system level" in line)
    assert "\x1b[" in heading
    assert "SPEC:" in out
    assert "\x1b[" in spec_line(tmp_path / "work" / "bank_system" / "java" / "spec.md")


def test_start_resume_note_before_spec(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    capsys.readouterr()
    assert load_session()["unlocked"] == 2
    assert main(["start", "bank_system", "python3", "--no-console"]) == 0
    out = capsys.readouterr().out
    spec_at = out.find("# Bank system level 2")
    assert spec_at != -1
    before = out[:spec_at]
    assert "NOTE:" in before
    assert "LEVEL 2" in before
    assert "--reset" in before or "back" in before


def test_start_on_tty_opens_live_menu(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    fake_in = io.StringIO("q\n")
    monkeypatch.setattr(fake_in, "isatty", lambda: True)
    monkeypatch.setattr(sys, "stdin", fake_in)
    monkeypatch.setattr(sys.stdout, "isatty", lambda: True)
    # StringIO has no fileno; stay on the readline menu path.
    monkeypatch.setattr("honepad.console._use_live", lambda *_a, **_k: False)
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    out = capsys.readouterr().out
    assert "1 run" in out
    assert "OK: quit" in out


def test_start_no_console_skips_menu_on_tty(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    fake_in = io.StringIO("q\n")
    monkeypatch.setattr(fake_in, "isatty", lambda: True)
    monkeypatch.setattr(sys, "stdin", fake_in)
    monkeypatch.setattr(sys.stdout, "isatty", lambda: True)
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    out = capsys.readouterr().out
    assert "1 run" not in out
    assert "OK: quit" not in out
    assert fake_in.read() == "q\n"


def test_bare_honepad_resumes_console(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("q\n"))
    assert main([]) == 0
    out = capsys.readouterr().out
    assert "1 run" in out
    assert "OK: quit" in out


def test_console_no_session_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["console"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "no session" in out


def test_vscode_no_session_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["vscode"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "no session" in out


def test_console_needs_both_args(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["console", "bank_system"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "both problem and lang" in out
    assert "NEXT:" in out
    assert "console bank_system java" in out


def test_vscode_needs_both_args(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["vscode", "bank_system"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "both problem and lang" in out
    assert "NEXT:" in out
    assert "vscode bank_system java" in out


def test_console_unimplemented_lang_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["console", "bank_system", "vb"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "vb" in out
    assert "no runner" in out
    assert "adapter=" not in out
    assert "factory job" not in out
    assert "NEXT:" in out
    assert "start bank_system java" in out


def test_console_unknown_lang_python_suggests_python3(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    code = main(["console", "bank_system", "python"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "unknown language: python" in out
    assert "FAIL: 'unknown language" not in out
    assert "python3" in out
    assert "NEXT:" in out
    assert "langs" in out
    assert "Traceback" not in out


def test_vscode_unknown_lang_python_suggests_python3(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    code = main(["vscode", "bank_system", "python", "--no-open"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code == 1
    assert "unknown language: python" in out
    assert "FAIL: 'unknown language" not in out
    assert "python3" in out
    assert "NEXT:" in out
    assert "langs" in out
    assert "Traceback" not in out


def _pipe_stdin(data: bytes) -> io.TextIOWrapper:
    read_fd, write_fd = os.pipe()
    os.write(write_fd, data)
    os.close(write_fd)
    return os.fdopen(read_fd, "r")


def test_live_menu_key_does_not_need_enter() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 1,
        "minutes": 90,
        "unlocked": 2,
    }
    stdin = _pipe_stdin(b"1q")
    try:
        got = _read_choice(session, stdin, io.StringIO(), live=True, clock_fn=lambda: 12)
    finally:
        stdin.close()
    assert got == "1"


def test_live_menu_key_drains_leftover() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 1,
        "minutes": 90,
        "unlocked": 2,
    }
    stdin = _pipe_stdin(b"12")
    try:
        got = _read_choice(session, stdin, io.StringIO(), live=True, clock_fn=lambda: 12)
        leftover = stdin.read()
    finally:
        stdin.close()
    assert got == "1"
    assert leftover == ""


def test_live_read_choice_timeout_reprints_time_up(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": int(time.time()),
        "minutes": 90,
        "unlocked": 1,
    }
    stdin = _pipe_stdin(b"q")
    stdout = io.StringIO()
    shown_time_up = [False]
    select_calls = {"n": 0}
    remaining_calls = {"n": 0}

    def fake_select(rlist, wlist, xlist, timeout=None):
        select_calls["n"] += 1
        if select_calls["n"] == 1:
            return [], [], []
        return list(rlist), [], []

    def fake_remaining(started_at: int, minutes: int, now: int | None = None) -> int:
        remaining_calls["n"] += 1
        return 60 if remaining_calls["n"] == 1 else 0

    monkeypatch.setattr("honepad.console.select.select", fake_select)
    monkeypatch.setattr("honepad.console.remaining_s", fake_remaining)
    try:
        got = _read_choice(
            session,
            stdin,
            stdout,
            live=True,
            clock_fn=None,
            shown_time_up=shown_time_up,
        )
    finally:
        stdin.close()
    assert got == "q"
    out = stdout.getvalue()
    assert shown_time_up[0] is True
    assert "TIME UP" in out
    assert out.count("TIME UP") == 1
    assert "will not unlock" in out.lower()


def test_live_menu_enter_alone_is_empty() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 1,
        "minutes": 90,
        "unlocked": 2,
    }
    stdin = _pipe_stdin(b"\n")
    try:
        got = _read_choice(session, stdin, io.StringIO(), live=True, clock_fn=lambda: 12)
    finally:
        stdin.close()
    assert got == ""


def test_live_prompt_is_clock_and_level_only() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 1,
        "minutes": 90,
        "unlocked": 2,
    }
    stdin = _pipe_stdin(b"q")
    buf = io.StringIO()
    try:
        got = _read_choice(session, stdin, buf, live=True, clock_fn=lambda: 12)
    finally:
        stdin.close()
    assert got == "q"
    out = buf.getvalue()
    assert "LEVEL 2" in out
    assert "00:12" in out
    assert "1 run" not in out
    assert "submit" not in out
    assert out.count("\n") == 1


def test_live_menu_space_then_key() -> None:
    session = {
        "problem": "bank_system",
        "lang": "java",
        "started_at": 1,
        "minutes": 90,
        "unlocked": 2,
    }
    stdin = _pipe_stdin(b" \t1")
    buf = io.StringIO()
    try:
        got = _read_choice(session, stdin, buf, live=True, clock_fn=lambda: 12)
    finally:
        stdin.close()
    assert got == "1"
    out = buf.getvalue()
    assert out.count("\n") == 1
    assert out.count("\r") == 2
    assert "1 run" not in out


def test_console_quit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("q\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=" in out
    assert "1 run" in out
    assert "2 submit" in out
    assert "2 submit (local)" in out
    assert "3 reset / back" in out
    assert "5 vscode" in out
    assert "OK: quit" in out
    assert "file://" in out


def test_confirm_unlock_live_y_prefix() -> None:
    stdin = io.StringIO("yrest")
    stdout = io.StringIO()
    assert _confirm_unlock(stdin, stdout, live=True) is True
    assert stdin.read() == ""


def test_confirm_unlock_live_yes_drains_leftover() -> None:
    stdin = io.StringIO("yes")
    stdout = io.StringIO()
    assert _confirm_unlock(stdin, stdout, live=True) is True
    assert stdin.read() == ""


def test_confirm_unlock_live_n() -> None:
    stdin = io.StringIO("n")
    stdout = io.StringIO()
    assert _confirm_unlock(stdin, stdout, live=True) is False


def test_confirm_unlock_line_yes() -> None:
    stdin = io.StringIO("yes\n")
    stdout = io.StringIO()
    assert _confirm_unlock(stdin, stdout, live=False) is True


def test_confirm_unlock_line_yrest() -> None:
    stdin = io.StringIO("yrest\n")
    stdout = io.StringIO()
    assert _confirm_unlock(stdin, stdout, live=False) is False


def _write_python_solution(tmp_path: Path) -> Path:
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    src = repo_root() / "langs" / "python3" / "problems" / "bank_system" / "solution.py"
    work.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    return work


def test_console_run_then_quit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("1\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    # cmd_run only prints these after traces actually ran; banner remaining_s= is not enough.
    assert "create_account" in out or "createAccount" in out
    assert "passed=" in out
    assert "FAIL " in out or "l1-" in out
    assert "remaining_s=" in out
    assert "OK: quit" in out


def test_console_run_does_not_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    _write_python_solution(tmp_path)
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("1\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert "passed=" in out
    assert "2 submit" in out
    assert out.count("LEVEL 1") >= 1
    assert out.count("honepad  bank_system") == 1


def test_live_menu_leftover_keys_do_not_submit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    _write_python_solution(tmp_path)
    capsys.readouterr()
    session = load_session()
    assert session is not None
    stdin = _pipe_stdin(b"12y")
    stdout = io.StringIO()
    try:
        code = loop_console(session, stdin=stdin, stdout=stdout, live=True)
    finally:
        stdin.close()
    out = stdout.getvalue() + capsys.readouterr().out
    assert code == 0
    assert "UNLOCKED" not in out
    assert load_session()["unlocked"] == 1
    assert "passed=" in out


def test_console_two_runs_keep_one_banner(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("1\n1\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert out.count("honepad  bank_system") == 1
    assert out.count("passed=") == 2
    assert "\n\n" in out


def test_console_submit_unlocks(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    _write_python_solution(tmp_path)
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("2\ny\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2
    assert "NOTE: local submit" in out
    assert "LEVEL 2" in out


def test_console_submit_cancel_keeps_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    _write_python_solution(tmp_path)
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("2\nn\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED" not in out
    assert "cancelled" in out.lower()
    assert load_session()["unlocked"] == 1
    assert "passed=" not in out


def test_console_last_level_submit_skips_unlock_prompt(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    _write_python_solution(tmp_path)
    session = load_session()
    assert session is not None
    session["unlocked"] = 4
    save_session(session)
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("2\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "Unlock?" not in out
    assert "cancelled" not in out.lower()
    assert "DONE: bank_system python3" in out
    assert "passed=" in out
    assert load_session()["cleared"] is True
    done_idx = out.find("DONE: bank_system python3")
    assert done_idx != -1
    after = out[done_idx:]
    assert "2 replay" in after
    assert "pass all traces to finish" not in after.lower()
    assert "NOTE: local submit" in out
    assert "NOTE: replay" not in out
    monkeypatch.setattr(sys, "stdin", io.StringIO("2\nq\n"))
    assert main(["console"]) == 0
    replay_out = capsys.readouterr().out
    assert "NOTE: replay. Same work-file test." in replay_out
    assert "NOTE: local submit" not in replay_out
    assert "Unlock?" not in replay_out


def test_banner_notes_extra_java_sources(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    work.parent.mkdir(parents=True)
    work.write_text("public class Simulation {}\n", encoding="utf-8")
    (work.parent / "Account.java").write_text(
        "class Simulation {}\npublic class Account {}\n",
        encoding="utf-8",
    )
    text = render_banner(
        {
            "problem": "bank_system",
            "lang": "java",
            "started_at": 100,
            "minutes": 90,
            "unlocked": 4,
            "cleared": True,
        }
    )
    assert "Account.java is ignored" in text
    assert "Put the Simulation class in Simulation.java" in text
    assert "DONE: bank_system java" in text


def test_console_reset(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("edited-by-candidate\n", encoding="utf-8")
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\nyes\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "Type yes" in out
    assert "OK: reset" in out
    assert "def create_account(" in work.read_text(encoding="utf-8")
    assert "edited-by-candidate" not in work.read_text(encoding="utf-8")


def test_console_reset_y_wipes_work(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("edited-by-candidate\n", encoding="utf-8")
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\ny\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "OK: reset" in out
    assert "def create_account(" in work.read_text(encoding="utf-8")
    assert "edited-by-candidate" not in work.read_text(encoding="utf-8")


def test_console_reset_n_keeps_work_and_hints(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("edited-by-candidate\n", encoding="utf-8")
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\nn\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "OK: reset" not in out
    assert "FAIL" in out
    assert "yes" in out.lower()
    assert "back" in out.lower()
    assert "all" in out.lower()
    assert work.read_text(encoding="utf-8") == "edited-by-candidate\n"


def test_console_reset_back_drops_one_level(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    work = _write_python_solution(tmp_path)
    assert main(["submit", "bank_system", "--lang", "python3"]) == 0
    assert load_session()["unlocked"] == 2
    assert "top_spenders" in work.read_text(encoding="utf-8")
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\nback\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "Type back" in out
    assert "OK: LEVEL 1" in out
    assert load_session()["unlocked"] == 1
    text = work.read_text(encoding="utf-8")
    assert "def create_account(" in text
    assert "def top_spenders(" not in text


def test_console_reset_all_starts_level1(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    work = _write_python_solution(tmp_path)
    assert main(["submit", "bank_system", "--lang", "python3"]) == 0
    assert load_session()["unlocked"] == 2
    started = int(load_session()["started_at"])
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\nall\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "Type all" in out
    assert "OK: LEVEL 1" in out
    after = load_session()
    assert after["unlocked"] == 1
    assert int(after["started_at"]) >= started
    text = work.read_text(encoding="utf-8")
    assert "def create_account(" in text
    assert "NotImplementedError" in text
    assert "def top_spenders(" not in text


def test_console_reset_back_at_level1_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\nback\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "already level 1" in out
    assert "NEXT: already LEVEL 1" in out
    assert load_session()["unlocked"] == 1


def test_start_reset_rewrites_workspace(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    work.write_text(
        (repo_root() / "langs" / "java" / "problems" / "bank_system" / "solution.java").read_text(
            encoding="utf-8"
        ),
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--lang", "java"]) == 0
    assert main(["vscode", "bank_system", "java", "--no-open"]) == 0
    public = tmp_path / "workspace" / "bank_system-java" / "public"
    assert (public / "spec" / "level2.md").is_file()
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    assert load_session()["unlocked"] == 1
    assert not (public / "spec" / "level2.md").exists()
    junit = (public / "src" / "test" / "java" / "PublicTracesTest.java").read_text(encoding="utf-8")
    assert "topSpenders" not in junit


def test_start_back_restarts_dead_clock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    _write_python_solution(tmp_path)
    assert main(["submit", "bank_system", "--lang", "python3"]) == 0
    session = load_session()
    assert session is not None
    session["started_at"] = 1
    session["minutes"] = 1
    (tmp_path / "session.json").write_text(json.dumps(session, indent=2) + "\n", encoding="utf-8")
    capsys.readouterr()
    assert main(["start", "bank_system", "python3", "--back", "--no-console"]) == 0
    out = capsys.readouterr().out
    assert load_session()["unlocked"] == 1
    assert "remaining_s=0" not in out
    assert "LEVEL 1" in out


def test_start_back_drops_unlock(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    work.write_text(
        (repo_root() / "langs" / "java" / "problems" / "bank_system" / "solution.java").read_text(
            encoding="utf-8"
        ),
        encoding="utf-8",
    )
    assert main(["submit", "bank_system", "--lang", "java"]) == 0
    assert load_session()["unlocked"] == 2
    capsys.readouterr()
    assert main(["start", "bank_system", "java", "--back", "--no-console"]) == 0
    out = capsys.readouterr().out
    assert "LEVEL 1" in out
    assert load_session()["unlocked"] == 1
    text = work.read_text(encoding="utf-8")
    assert "createAccount" in text
    assert "topSpenders" not in text


def test_console_reset_without_yes_keeps_work(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("edited-by-candidate\n", encoding="utf-8")
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "Type yes" in out
    assert "OK: reset" not in out
    assert work.read_text(encoding="utf-8") == "edited-by-candidate\n"


def test_console_spec(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("4\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "level" in out.lower()
    assert "create" in out.lower()


def test_dispatch_unknown_prints_keys() -> None:
    session = {
        "problem": "bank_system",
        "lang": "python3",
        "started_at": 100,
        "minutes": 90,
        "unlocked": 1,
    }
    buf = io.StringIO()
    assert dispatch("9", session, buf) == 1
    out = buf.getvalue()
    assert "FAIL: unknown option" in out
    assert "Keys:" in out
    assert "1 run" in out
    assert "2 submit" in out
    assert "3 reset" in out
    assert "q quit" in out


def test_start_reset_and_back_prints_next(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--back"]) == 1
    out = capsys.readouterr().out
    assert "use --reset or --back" in out
    assert "NEXT:" in out
    assert "start --reset" in out


def test_start_back_wrong_problem_prints_next(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["start", "workers", "python3", "--back", "--no-console"]) == 1
    out = capsys.readouterr().out
    assert "--back needs the current problem" in out
    assert "NEXT:" in out
    assert "start bank_system python3 --back" in out


def test_start_back_already_level1_prints_next(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["start", "bank_system", "python3", "--back", "--no-console"]) == 1
    out = capsys.readouterr().out
    assert "already level 1" in out
    assert "NEXT:" in out
    assert "start" in out


def test_dispatch_vscode_opens_workspace(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    session = load_session()
    assert session is not None
    opened: list[Path] = []

    def _open(path: Path) -> int:
        opened.append(path)
        return 0

    popen_calls: list[object] = []
    monkeypatch.setattr("honepad.console.open_vscode", _open)
    monkeypatch.setattr(
        "honepad.workspace.subprocess.Popen",
        lambda *args, **kwargs: popen_calls.append((args, kwargs)),
    )
    buf = io.StringIO()
    assert dispatch("5", session, buf) == 0
    expected = tmp_path / "workspace" / "bank_system-python3" / "honepad.code-workspace"
    assert opened == [expected]
    assert popen_calls == []
    out = buf.getvalue()
    assert "WORKSPACE:" in out
    assert "file://" in out
    assert "SPEC:" in out
    assert "current.md" in out
    assert "TESTS:" in out
    assert "test_public.py" in out


def test_dispatch_write_workspace_fail_closed(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    session = load_session()
    assert session is not None

    def _boom(*_args: object, **_kwargs: object) -> Path:
        raise ValueError("boom")

    monkeypatch.setattr("honepad.console.write_workspace", _boom)
    buf = io.StringIO()
    assert dispatch("5", session, buf) == 1
    out = buf.getvalue()
    assert "FAIL:" in out
    assert "boom" in out
    assert "Traceback" not in out


def test_dispatch_vscode_recreates_missing_java_work(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    assert work.is_file()
    work.unlink()
    session = load_session()
    assert session is not None
    monkeypatch.setattr("honepad.console.open_vscode", lambda _path: 0)
    buf = io.StringIO()
    assert dispatch("5", session, buf) == 0
    assert work.is_file()
    assert "class Simulation" in work.read_text(encoding="utf-8")
    public_sim = (
        tmp_path
        / "workspace"
        / "bank_system-java"
        / "public"
        / "src"
        / "main"
        / "java"
        / "Simulation.java"
    )
    assert public_sim.exists()
    assert "FAIL:" not in buf.getvalue()


def test_cmd_vscode_no_open_recreates_missing_java_work(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    assert work.is_file()
    work.unlink()
    assert main(["vscode", "--no-open"]) == 0
    out = capsys.readouterr().out
    assert work.is_file()
    assert "class Simulation" in work.read_text(encoding="utf-8")
    assert "FAIL:" not in out
    assert "WORKSPACE:" in out
    assert "SPEC:" in out


@pytest.mark.skipif(shutil.which("mvn") is None, reason="mvn not installed")
def test_java_junit_l1_stub_fails_without_npe(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    dest = write_workspace("bank_system", "java", 1)
    public = dest.parent / "public"
    result = subprocess.run(
        ["mvn", "-q", "-f", str(public / "pom.xml"), "test"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    chunks = [result.stdout, result.stderr]
    surefire = public / "target" / "surefire-reports"
    if surefire.is_dir():
        for path in sorted(surefire.iterdir()):
            if path.is_file():
                chunks.append(path.read_text(encoding="utf-8", errors="replace"))
    output = "".join(chunks)
    assert "NullPointerException" not in output


def test_write_workspace_java_missing_work_fails_closed(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    work.unlink()
    with pytest.raises(ValueError, match="work file missing"):
        write_workspace("bank_system", "java", 1)
    public_sim = (
        tmp_path
        / "workspace"
        / "bank_system-java"
        / "public"
        / "src"
        / "main"
        / "java"
        / "Simulation.java"
    )
    assert not public_sim.exists()
    public = tmp_path / "workspace" / "bank_system-java" / "public"
    assert not (public / "cases.json").exists()


def test_write_workspace_python_missing_work_fails_closed(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.unlink()
    with pytest.raises(ValueError, match="work file missing"):
        write_workspace("bank_system", "python3", 1)
    public = tmp_path / "workspace" / "bank_system-python3" / "public"
    assert not (public / "test_public.py").exists()
    assert not (public / "cases.json").exists()


def test_vscode_no_open_writes_public_tests(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    assert main(["vscode", "--no-open"]) == 0
    out = capsys.readouterr().out
    dest = tmp_path / "workspace" / "bank_system-java" / "honepad.code-workspace"
    assert dest.is_file()
    assert "WORKSPACE:" in out
    assert "file://" in out
    assert "SPEC:" in out
    assert "current.md" in out
    assert "TESTS:" in out
    assert "PublicTracesTest.java" in out
    payload = json.loads(dest.read_text(encoding="utf-8"))
    names = [folder["name"] for folder in payload["folders"]]
    assert names == ["spec", "public-tests", "work"]
    public = dest.parent / "public"
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    folders = payload["folders"]
    assert folders[0]["path"] == str((public / "spec").resolve())
    assert folders[1]["path"] == str(public.resolve())
    assert folders[2]["path"] == str(work.parent.resolve())
    assert (work.parent / "spec.md").is_file()
    assert payload["settings"]["java.import.maven.enabled"] is True
    assert payload["settings"]["java.project.explorer.showNonJavaResources"] is True
    assert "**/work/**" in payload["settings"]["java.import.exclusions"]
    work_settings = json.loads(
        (work.parent / ".vscode" / "settings.json").read_text(encoding="utf-8")
    )
    assert work_settings["java.import.maven.enabled"] is False
    assert work_settings["java.import.gradle.enabled"] is False
    assert "vscjava.vscode-java-pack" in payload["extensions"]["recommendations"]
    cases = json.loads((public / "cases.json").read_text(encoding="utf-8"))
    unlocked = load_cases("bank_system", 1)
    assert cases == unlocked
    assert all(int(case["level"]) <= 1 for case in cases)
    assert (public / "Adapter.java").is_file()
    assert (public / "MiniJson.java").is_file()
    assert (public / "src" / "main" / "java" / "Simulation.java").is_file()
    assert (public / "src" / "test" / "java" / "PublicTracesTest.java").is_file()
    junit = (public / "src" / "test" / "java" / "PublicTracesTest.java").read_text(encoding="utf-8")
    assert junit.count("@Test") == len(unlocked)
    for case in unlocked:
        assert java_ident(case["id"]) in junit
    assert "org.junit.jupiter.api.Test" in junit
    assert "createAccount" in junit
    assert "mergeAccounts" not in junit
    assert "import static org.junit.jupiter.api.Assertions.assertNull;" in junit
    assert "assertNull(" in junit
    assert 'assertEquals((Object) 500, sim.deposit(2, "acc1", 500));' in junit
    assert "assertEquals(500, sim.deposit" not in junit
    assert "(Object) true" in junit
    assert 'assertEquals((Object) true, sim.createAccount(1, "acc1"));' in junit
    assert (public / "pom.xml").is_file()
    pom = (public / "pom.xml").read_text(encoding="utf-8")
    assert "junit-jupiter" in pom
    assert (public / "run-public.sh").is_file()
    assert (public / "spec.md").is_file()
    assert (public / "src" / "main" / "java" / "spec.md").is_file()
    assert "create_account" in (public / "src" / "main" / "java" / "spec.md").read_text(
        encoding="utf-8"
    )
    assert (public / "spec" / "level1.md").is_file()
    assert not (public / "spec" / "level2.md").exists()
    assert (public / "spec.md").read_text(encoding="utf-8").startswith("# Bank system level 1")
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    labels = [task["label"] for task in tasks["tasks"]]
    assert "Run public tests" in labels
    assert "Run JUnit tests" in labels
    by_label = {task["label"]: task for task in tasks["tasks"]}
    junit = by_label["Run JUnit tests"]
    javac = by_label["Run public tests (javac)"]
    assert "public-tests" in junit["options"]["cwd"]
    assert "public-tests" in javac["options"]["cwd"]
    assert "public-tests" in javac["command"]
    assert "workspaceFolder" not in json.dumps(by_label["Run public tests"])
    public_run = json.dumps(by_label["Run public tests"])
    assert '"run"' in public_run
    assert "submit" not in public_run


def test_write_workspace_includes_unlocked_level_specs(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    ensure_work_copy("bank_system", "java", reset=False, level=2)
    dest = write_workspace("bank_system", "java", 2)
    public = dest.parent / "public"
    spec = (public / "spec.md").read_text(encoding="utf-8")
    assert spec.startswith("# Bank system level 2")
    assert "top_spenders" in spec
    assert '["acc1(500)", "acc2(0)"]' in spec
    assert (public / "level2.md").is_file()
    assert (public / "spec" / "level2.md").read_text(encoding="utf-8") == spec
    payload = json.loads(dest.read_text(encoding="utf-8"))
    names = [folder["name"] for folder in payload["folders"]]
    assert names[0] == "spec"
    assert names[1] == "public-tests"
    assert payload["folders"][0]["path"] == str((public / "spec").resolve())


def test_unlock_prints_spec_and_refreshes_workspace(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    assert main(["vscode", "--no-open"]) == 0
    capsys.readouterr()
    public = tmp_path / "workspace" / "bank_system-java" / "public"
    assert (public / "spec.md").read_text(encoding="utf-8").startswith("# Bank system level 1")
    assert not (public / "level2.md").exists()
    assert main(["submit", "bank_system", "--kind", "solution"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert "# Bank system level 2" in out
    assert "top_spenders" in out
    assert load_session()["unlocked"] == 2
    spec = (public / "spec.md").read_text(encoding="utf-8")
    assert spec.startswith("# Bank system level 2")
    java_spec = public / "src" / "main" / "java" / "spec.md"
    assert java_spec.is_file()
    assert java_spec.read_text(encoding="utf-8").startswith("# Bank system level 2")
    assert (public / "level2.md").is_file()
    assert (public / "spec" / "level2.md").is_file()


def test_workspace_readme_names_public_traces(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    dest = write_workspace("bank_system", "java", 1)
    readme = (dest.parent / "public" / "README.md").read_text(encoding="utf-8")
    assert "public traces" in readme
    assert "honepad run" in readme
    assert "same public traces honepad run uses" in readme
    assert "no separate hidden suite" in readme
    assert "Hidden tests are not here" not in readme
    assert "Current spec:" in readme
    assert "spec/level1.md" in readme


@pytest.mark.skipif(shutil.which("mvn") is None, reason="mvn not installed")
def test_java_junit_project_compiles(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    dest = write_workspace("bank_system", "java", 1)
    public = dest.parent / "public"
    result = subprocess.run(
        ["mvn", "-q", "-f", str(public / "pom.xml"), "test-compile"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


@pytest.mark.skipif(shutil.which("mvn") is None, reason="mvn not installed")
def test_java_junit_l2_project_compiles(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    ensure_work_copy("bank_system", "java", reset=False, level=2)
    dest = write_workspace("bank_system", "java", 2)
    public = dest.parent / "public"
    junit = (public / "src" / "test" / "java" / "PublicTracesTest.java").read_text(encoding="utf-8")
    assert "(Object) List.of" in junit
    result = subprocess.run(
        ["mvn", "-q", "-f", str(public / "pom.xml"), "test-compile"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_workspace_python_skips_java_adapter(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    dest = write_workspace("bank_system", "python3", 1)
    public = dest.parent / "public"
    assert (public / "cases.json").is_file()
    assert not (public / "Adapter.java").exists()
    assert not (public / "run-public.sh").exists()
    assert not (public / "pom.xml").exists()
    assert (public / "test_public.py").is_file()
    pytest_src = (public / "test_public.py").read_text(encoding="utf-8")
    unlocked = load_cases("bank_system", 1)
    assert pytest_src.count("def test_") == len(unlocked)
    for case in unlocked:
        assert pytest_ident(case["id"]) in pytest_src
    assert "def test_l1_create()" in pytest_src
    assert "create_account" in pytest_src
    assert "merge_accounts" not in pytest_src
    payload = dest.read_text(encoding="utf-8")
    folders = json.loads(payload)["folders"]
    names = [folder["name"] for folder in folders]
    assert names == ["spec", "public-tests", "work"]
    assert "java.import.maven" not in payload
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    labels = [task["label"] for task in tasks["tasks"]]
    assert any("pytest" in label.lower() for label in labels)
    by_label = {task["label"]: task for task in tasks["tasks"]}
    pytest_task = by_label["Run pytest"]
    assert "public-tests" in pytest_task["options"]["cwd"]
    assert "public-tests" not in json.dumps(by_label["Run public tests"])


def test_start_without_workspace_does_not_create_one(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    root = tmp_path / "workspace" / "bank_system-python3"
    assert not root.exists()
    assert main(["start", "bank_system", "python3", "--no-console"]) == 0
    assert not root.exists()


def test_start_refreshes_stale_workspace_cases(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    dest = write_workspace("bank_system", "python3", 1)
    public = dest.parent / "public"
    cases_path = public / "cases.json"
    pytest_path = public / "test_public.py"
    cases_path.write_text("[]\n", encoding="utf-8")
    pytest_path.write_text("from work import Simulation\n", encoding="utf-8")
    assert main(["start", "bank_system", "python3", "--no-console"]) == 0
    fresh = load_cases("bank_system", 1)
    assert json.loads(cases_path.read_text(encoding="utf-8")) == fresh
    text = pytest_path.read_text(encoding="utf-8")
    assert text.count("def test_") == len(fresh)
    assert "def test_l1_create()" in text


def test_run_refreshes_stale_workspace_cases(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    dest = write_workspace("bank_system", "python3", 1)
    public = dest.parent / "public"
    cases_path = public / "cases.json"
    pytest_path = public / "test_public.py"
    cases_path.write_text("[]\n", encoding="utf-8")
    pytest_path.write_text("from work import Simulation\n", encoding="utf-8")
    main(["run", "bank_system", "--kind", "work"])
    fresh = load_cases("bank_system", 1)
    assert json.loads(cases_path.read_text(encoding="utf-8")) == fresh
    text = pytest_path.read_text(encoding="utf-8")
    assert text.count("def test_") == len(fresh)
    assert "def test_l1_create()" in text


def test_write_workspace_breaks_cases_hardlink_to_pack(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    dest = write_workspace("bank_system", "java", 1)
    public = dest.parent / "public"
    pack_adapter = repo_root() / "langs" / "java" / "Adapter.java"
    original = pack_adapter.read_bytes()
    cases = public / "cases.json"
    cases.unlink()
    os.link(pack_adapter, cases)
    try:
        assert cases.stat().st_ino == pack_adapter.stat().st_ino
        write_workspace("bank_system", "java", 1)
        assert pack_adapter.read_bytes() == original
        assert cases.is_file()
        assert not cases.is_symlink()
        assert cases.stat().st_ino != pack_adapter.stat().st_ino
    finally:
        if pack_adapter.read_bytes() != original:
            pack_adapter.write_bytes(original)


def test_write_workspace_breaks_adapter_symlink_to_pack(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    dest = write_workspace("bank_system", "java", 1)
    public = dest.parent / "public"
    pack_adapter = repo_root() / "langs" / "java" / "Adapter.java"
    original = pack_adapter.read_bytes()
    planted = public / "Adapter.java"
    planted.unlink()
    planted.symlink_to(pack_adapter)
    try:
        write_workspace("bank_system", "java", 1)
        assert pack_adapter.read_bytes() == original
        assert planted.exists()
        assert not planted.is_symlink() or planted.resolve() != pack_adapter.resolve()
    finally:
        if pack_adapter.read_bytes() != original:
            pack_adapter.write_bytes(original)


def test_write_workspace_refuses_public_dir_symlink(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    pack = repo_root() / "langs" / "java"
    original_names = {path.name for path in pack.iterdir()}
    work_dir = tmp_path / "work" / "bank_system" / "java"
    assert work_dir.is_dir()
    work_before = {path.name for path in work_dir.iterdir()}
    root = tmp_path / "workspace" / "bank_system-java"
    root.mkdir(parents=True, exist_ok=True)
    public = root / "public"
    if public.exists() or public.is_symlink():
        if public.is_dir() and not public.is_symlink():
            shutil.rmtree(public)
        else:
            public.unlink()
    public.symlink_to(work_dir)
    polluters = ("cases.json", "pom.xml", "README.md", "run-public.sh", "spec.md")
    try:
        with pytest.raises((ValueError, RuntimeError), match="symlink"):
            write_workspace("bank_system", "java", 1)
        assert public.is_symlink()
        assert {path.name for path in pack.iterdir()} == original_names
        assert {path.name for path in work_dir.iterdir()} == work_before
        for name in polluters:
            if name not in work_before:
                assert not (work_dir / name).exists()
            assert not (pack / name).exists()
    finally:
        if public.is_symlink():
            public.unlink()


def test_write_workspace_refuses_workspace_dir_symlink_outside(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    root = tmp_path / "workspace" / "bank_system-java"
    outside = tmp_path / "outside-workspace"
    outside.mkdir()
    marker = outside / "keep.txt"
    marker.write_text("keep-outside\n", encoding="utf-8")
    root.parent.mkdir(parents=True, exist_ok=True)
    if root.exists() or root.is_symlink():
        if root.is_dir() and not root.is_symlink():
            shutil.rmtree(root)
        else:
            root.unlink()
    root.symlink_to(outside)
    polluters = (
        "public",
        "honepad.code-workspace",
        "cases.json",
        "pom.xml",
        "README.md",
        "spec.md",
        "spec",
    )
    try:
        with pytest.raises((ValueError, RuntimeError), match="symlink"):
            write_workspace("bank_system", "java", 1)
        assert root.is_symlink()
        assert root.resolve() == outside.resolve()
        assert marker.read_text(encoding="utf-8") == "keep-outside\n"
        assert {path.name for path in outside.iterdir()} == {"keep.txt"}
        for name in polluters:
            assert not (outside / name).exists()
    finally:
        if root.is_symlink():
            root.unlink()


def test_write_workspace_refuses_spec_dir_symlink_outside(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    dest = write_workspace("bank_system", "java", 1)
    public = dest.parent / "public"
    assert public.is_dir()
    spec = public / "spec"
    outside = tmp_path / "outside-spec"
    outside.mkdir()
    marker = outside / "keep.txt"
    marker.write_text("keep-outside\n", encoding="utf-8")
    if spec.exists() or spec.is_symlink():
        if spec.is_dir() and not spec.is_symlink():
            shutil.rmtree(spec)
        else:
            spec.unlink()
    spec.symlink_to(outside)
    try:
        with pytest.raises((ValueError, RuntimeError), match="symlink"):
            write_workspace("bank_system", "java", 1)
        assert spec.is_symlink()
        assert spec.resolve() == outside.resolve()
        assert marker.read_text(encoding="utf-8") == "keep-outside\n"
        assert {path.name for path in outside.iterdir()} == {"keep.txt"}
        for name in ("current.md", "level1.md"):
            assert not (outside / name).exists()
    finally:
        if spec.is_symlink():
            spec.unlink()


def test_link_or_copy_falls_back_on_oserror(tmp_path: Path, monkeypatch) -> None:
    src = tmp_path / "work.java"
    dest = tmp_path / "Simulation.java"
    src.write_text("class Simulation {}\n", encoding="utf-8")

    def _fail(self: Path, *args: object, **kwargs: object) -> None:
        raise OSError("no symlink")

    monkeypatch.setattr(Path, "symlink_to", _fail)
    _link_or_copy(src, dest)
    assert dest.is_file()
    assert not dest.is_symlink()
    assert dest.read_text(encoding="utf-8") == "class Simulation {}\n"


def test_open_vscode_detaches_from_console_tty(monkeypatch, tmp_path: Path, capsys) -> None:
    captured: list[dict[str, object]] = []

    def _popen(*_args: object, **kwargs: object) -> object:
        captured.append(kwargs)
        return object()

    monkeypatch.setattr(
        "honepad.workspace.shutil.which",
        lambda name: "/usr/bin/code" if name == "code" else None,
    )
    monkeypatch.setattr("honepad.workspace.subprocess.Popen", _popen)
    path = tmp_path / "honepad.code-workspace"
    path.write_text("{}\n", encoding="utf-8")
    assert open_vscode(path) == 0
    assert captured
    kwargs = captured[0]
    assert kwargs.get("start_new_session") is True or kwargs.get("stdin") is subprocess.DEVNULL
    assert kwargs["stdin"] is subprocess.DEVNULL
    assert kwargs["stdout"] is subprocess.DEVNULL
    assert kwargs["stderr"] is subprocess.DEVNULL
    assert kwargs["start_new_session"] is True
    out = capsys.readouterr().out
    assert "OK:" in out
    assert "FAIL:" not in out
    assert "file://" in out


def test_write_workspace_task_cwd_is_public_tests(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    dest = write_workspace("bank_system", "java", 1)
    public = dest.parent / "public"
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    for task in tasks["tasks"]:
        blob = json.dumps(task)
        if task["label"] == "Run public tests":
            assert "workspaceFolder:public-tests" not in blob
            continue
        assert "public-tests" in blob
        cwd = task.get("options", {}).get("cwd", "")
        command = str(task.get("command", ""))
        assert "public-tests" in cwd or "public-tests" in command


def test_vscode_missing_code_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr("honepad.workspace.shutil.which", lambda _name: None)
    assert main(["vscode"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "code" in out
    assert "file://" in out
    assert "Install" in out
    assert "PATH" in out


def test_workspace_has_submit_task_not_default(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    dest = write_workspace("bank_system", "python3", 1)
    public = dest.parent / "public"
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    by_label = {task["label"]: task for task in tasks["tasks"]}
    assert "Submit (unlock next level)" in by_label
    submit = by_label["Submit (unlock next level)"]
    blob = json.dumps(submit)
    assert "submit" in blob
    assert "--confirm" in blob
    assert "${input:unlockConfirm}" in blob
    assert "public-tests" in submit["options"]["cwd"]
    inputs = {item["id"]: item for item in tasks.get("inputs", [])}
    assert "unlockConfirm" in inputs
    assert "y" in inputs["unlockConfirm"]["options"]
    assert "n" in inputs["unlockConfirm"]["options"]
    default = by_label["Run public tests"]
    assert default["group"]["isDefault"] is True
    assert "submit" not in json.dumps(default)
    group = submit.get("group")
    if isinstance(group, dict):
        assert group.get("isDefault") is not True
    run_args = [str(item) for item in default["args"]]
    submit_args = [str(item) for item in submit["args"]]
    assert "--kind" in run_args
    assert "work" in run_args
    assert run_args[run_args.index("--kind") + 1] == "work"
    assert "--kind" in submit_args
    assert "work" in submit_args
    assert submit_args[submit_args.index("--kind") + 1] == "work"
    readme = (public / "README.md").read_text(encoding="utf-8")
    assert "Submit / Replay" in readme
    assert "later level is still locked" in readme
    assert "-m honepad run bank_system --lang python3 --kind work" in readme
    assert "-m honepad submit bank_system --lang python3 --kind work" in readme


def test_workspace_last_level_replay_task_omits_unlock_confirm(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    dest = write_workspace("bank_system", "python3", 4)
    public = dest.parent / "public"
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    by_label = {task["label"]: task for task in tasks["tasks"]}
    assert "Submit last level" in by_label
    assert "Replay last level" not in by_label
    assert "Submit (unlock next level)" not in by_label
    submit = by_label["Submit last level"]
    blob = json.dumps(submit)
    assert "submit" in blob
    assert "--confirm" not in blob
    assert "${input:unlockConfirm}" not in blob
    assert "inputs" not in tasks
    default = by_label["Run public tests"]
    assert default["group"]["isDefault"] is True
    readme = (public / "README.md").read_text(encoding="utf-8")
    assert "Submit last level" in readme
    assert "Replay last level" not in readme
    assert "Submit / Replay" not in readme
    assert "later level is still locked" not in readme
    assert "No y / n (nothing unlocks)" in readme
    dest = write_workspace("bank_system", "python3", 4, cleared=True)
    public = dest.parent / "public"
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    by_label = {task["label"]: task for task in tasks["tasks"]}
    assert "Replay last level" in by_label
    assert "Submit last level" not in by_label
    replay = by_label["Replay last level"]
    blob = json.dumps(replay)
    assert "submit" in blob
    assert "--confirm" not in blob
    assert "inputs" not in tasks
    readme = (public / "README.md").read_text(encoding="utf-8")
    assert "Replay last level" in readme
    assert "Submit last level" not in readme
    assert "Submit / Replay" not in readme
    assert "later level is still locked" not in readme
    assert "No y / n unlock" in readme


def test_workspace_run_task_kind_work_mismatch_does_not_replay_solution(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    bank_work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    bank_work.parent.mkdir(parents=True, exist_ok=True)
    bank_work.write_text("class Simulation:\n    pass\n", encoding="utf-8")
    dest = write_workspace("bank_system", "python3", 1)
    public = dest.parent / "public"
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    by_label = {task["label"]: task for task in tasks["tasks"]}
    run_args = [str(item) for item in by_label["Run public tests"]["args"]]
    assert run_args[:2] == ["-m", "honepad"]
    task_args = run_args[2:]
    bank_work.unlink()
    code = main(task_args)
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL:" in out
    assert "work file missing" in out or "work.py" in out
    assert "UNLOCKED" not in out
    assert "\nOK\n" not in out
    assert not out.strip().endswith("OK")
    assert "through LEVEL 4 passed=" not in out
    session = load_session()
    assert session is not None
    assert session["problem"] == "workers"


def test_home_short_folds_the_home_prefix(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    assert home_short(tmp_path / ".honepad" / "work.py") == "~/.honepad/work.py"
    assert home_short("/elsewhere/work.py") == "/elsewhere/work.py"
    assert home_short(tmp_path) == "~"


def test_home_short_does_not_fold_a_sibling_of_home(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path / "me"))
    assert home_short(tmp_path / "meet" / "work.py") == str(tmp_path / "meet" / "work.py")


def test_file_link_label_is_home_short(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    target = tmp_path / ".honepad" / "work.py"
    text = file_link(target)
    assert "~/.honepad/work.py" in text
    assert file_uri(target) in text


def test_level_dots_are_empty_without_color(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    assert level_dots(2, 4) == ""


def test_level_dots_clamp_past_the_last_level(monkeypatch) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    assert level_dots(9, 4).count("\u25cf") == 4
    assert level_dots(9, 4).count("\u25cb") == 0
    assert level_dots(0, 0) == ""


def test_level_dots_emit_no_empty_escape_pairs(monkeypatch) -> None:
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setenv("FORCE_COLOR", "1")
    full = level_dots(4, 4)
    assert full.count("\x1b[0m") == 1
    assert "\u25cb" not in full
    assert level_dots(0, 4).count("\x1b[0m") == 1
    assert meter(10, 10, cells=4).count("\x1b[0m") == 1


def test_meter_is_ascii_without_color(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    assert meter(5, 10, cells=10) == "[#####-----]"
    assert meter(10, 10, cells=10) == "[##########]"
    assert meter(0, 0) == ""


def test_render_pass_keeps_the_level_and_count(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    text = render_pass("bank_system", "java", 2, 13)
    assert "PASS  bank_system java LEVEL 2" in text
    assert "13 traces" in text
    assert "1 traces" not in text


def test_render_pass_says_trace_once(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    assert "1 trace " in render_pass("bank_system", "java", 1, 1)


def test_render_fail_keeps_the_greppable_tokens(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    text = render_fail(
        problem="bank_system",
        lang="java",
        level=2,
        case="l2-top",
        index=7,
        call="topSpenders(9, 3)",
        expected="True",
        actual="False",
        passed=11,
        total=13,
    )
    assert "FAIL " in text
    assert "expected=True" in text
    assert "actual=False" in text
    assert "topSpenders(9, 3)" in text
    assert "l2-top" in text
    assert "call #7" in text
    assert "2 cases short" in text
    assert "11/13 traces" in text


def test_render_fail_counts_one_case_singular(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    text = render_fail(
        problem="workers",
        lang="python3",
        level=1,
        case="l1-a",
        index=0,
        call="add_worker(1, 'w')",
        expected="None",
        actual="0",
        passed=4,
        total=5,
    )
    assert "1 case short" in text


def test_columns_number_down_each_column(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    rows = columns(["a", "b", "c", "d"], width=14, indent="")
    assert rows == ["1  a  3  c", "2  b  4  d"]


def test_columns_fall_back_to_one_per_row_when_narrow(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    rows = columns(["alpha", "beta"], width=1, indent="")
    assert rows == ["1  alpha", "2  beta"]
    assert columns([]) == []


def test_term_width_is_clamped(monkeypatch) -> None:
    monkeypatch.setattr(
        "honepad.term.shutil.get_terminal_size", lambda _d: os.terminal_size((9, 2))
    )
    assert term_width() == 40
    monkeypatch.setattr(
        "honepad.term.shutil.get_terminal_size", lambda _d: os.terminal_size((500, 2))
    )
    assert term_width() == 120


def test_render_fail_explains_the_exception_sentinel(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    args = dict(
        problem="bank_system",
        lang="python3",
        level=1,
        case="l1-create",
        index=0,
        call="create_account(1, 'acc1')",
        expected="True",
        actual="'exc:NotImplementedError'",
        passed=0,
        total=6,
    )
    plain = render_fail(**args)
    assert "raised" not in plain
    told = render_fail(**args, raised="NotImplementedError")
    assert "the call raised NotImplementedError instead of returning" in told
    assert "actual='exc:NotImplementedError'" in told


def test_render_help_leaves_the_closing_rule_to_the_caller(monkeypatch) -> None:
    monkeypatch.setenv("NO_COLOR", "1")
    text = render_help()
    assert text.startswith("-- keys")
    assert not text.rstrip().endswith("--")


def test_fresh_stub_run_explains_why_every_case_failed(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    monkeypatch.setenv("NO_COLOR", "1")
    assert main(["start", "bank_system", "python3", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system"]) == 1
    out = capsys.readouterr().out
    assert "the call raised NotImplementedError instead of returning" in out
    assert "cases short" in out
    assert "more failing cases not shown" in out
