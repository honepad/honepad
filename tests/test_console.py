import io
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.console import _read_choice, dispatch, render_banner
from honepad.javatest import java_ident
from honepad.pythontest import pytest_ident
from honepad.session import ensure_work_copy, load_session
from honepad.term import (
    color_enabled,
    file_link,
    file_uri,
    format_clock,
    paint_spec,
    render_menu,
    spec_line,
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


def test_color_disabled_without_tty(monkeypatch) -> None:
    monkeypatch.delenv("FORCE_COLOR", raising=False)
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setattr(sys.stdout, "isatty", lambda: False)
    assert color_enabled() is False


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
    assert "honepad  bank_system  java  unlocked=2" in text


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
    assert "unlocked=2" in text
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
    first = out.splitlines()[0]
    assert first.startswith("\x1b[")
    assert "SPEC:" in out
    assert "\x1b[" in spec_line(tmp_path / "work" / "bank_system" / "java" / "spec.md")


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
    assert "3 reset work" in out
    assert "5 vscode" in out
    assert "OK: quit" in out
    assert "file://" in out


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


def test_console_submit_unlocks(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    _write_python_solution(tmp_path)
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("2\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2
    assert "NOTE: local submit" in out


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
    assert "OK: unlocked=1" in out
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
    assert "OK: unlocked=1" in out
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
    assert load_session()["unlocked"] == 1


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
    assert "unlocked=1" in out
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
    assert "public-tests" in submit["options"]["cwd"]
    default = by_label["Run public tests"]
    assert default["group"]["isDefault"] is True
    assert "submit" not in json.dumps(default)
    group = submit.get("group")
    if isinstance(group, dict):
        assert group.get("isDefault") is not True
    readme = (public / "README.md").read_text(encoding="utf-8")
    assert "Submit (unlock next level)" in readme
