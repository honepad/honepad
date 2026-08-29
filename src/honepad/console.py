"""Live practice console: numbered menu, remaining_s clock, vscode."""

from __future__ import annotations

import argparse
import select
import sys
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from typing import Any, TextIO

from honepad.catalog import language
from honepad.runner import _RUNNERS
from honepad.session import (
    ensure_session,
    ensure_work_copy,
    load_session,
    note_clock_restarted,
    remaining_s,
    work_src,
)
from honepad.term import file_link, format_clock, invocation, start_next, work_line
from honepad.traces import problem_dir
from honepad.workspace import open_vscode, public_test_file, workspace_dir, write_workspace

_MENU = "1 run  2 submit (local)  3 reset work  4 spec  5 vscode  q quit"


def render_banner(session: dict[str, Any], now: int | None = None) -> str:
    problem = str(session["problem"])
    lang = str(session["lang"])
    unlocked = int(session["unlocked"])
    left = remaining_s(int(session["started_at"]), int(session["minutes"]), now)
    work = work_src(problem, lang)
    lines = [
        f"honepad  {problem}  {lang}  unlocked={unlocked}  "
        f"remaining_s={left}  [{format_clock(left)}]",
        work_line(work),
    ]
    if left == 0:
        lines.append("TIME UP: submit will not unlock.")
        lines.append("NOTE: a new clock is quit then start (keeps work). 3 deletes the file.")
    return "\n".join(lines)


def cmd_console(args: argparse.Namespace) -> int:
    try:
        session = _load_or_start(args)
        ensure_work_copy(
            str(session["problem"]),
            str(session["lang"]),
            reset=False,
            level=int(session["unlocked"]),
        )
    except (KeyError, ValueError, FileNotFoundError, OSError) as exc:
        _print_fail(exc)
        return 1
    return loop_console(session, stdin=sys.stdin, stdout=sys.stdout)


def cmd_vscode(args: argparse.Namespace) -> int:
    try:
        session = _load_or_start(args)
        ensure_work_copy(
            str(session["problem"]),
            str(session["lang"]),
            reset=False,
            level=int(session["unlocked"]),
        )
        path = write_workspace(
            str(session["problem"]),
            str(session["lang"]),
            int(session["unlocked"]),
        )
        print(f"WORKSPACE: {file_link(path)}")
        _print_spec_link(str(session["problem"]), str(session["lang"]))
        _print_tests(str(session["problem"]), str(session["lang"]))
        if args.no_open:
            print("OK: wrote workspace")
            return 0
        return open_vscode(path)
    except (KeyError, ValueError, FileNotFoundError, OSError) as exc:
        _print_fail(exc)
        return 1


def loop_console(
    session: dict[str, Any],
    *,
    stdin: TextIO,
    stdout: TextIO,
    live: bool | None = None,
) -> int:
    last = 0
    use_live = _use_live(stdin, stdout) if live is None else live
    try:
        while True:
            session = load_session() or session
            stdout.write(render_banner(session) + "\n")
            stdout.flush()
            line = _read_choice(session, stdin, stdout, live=use_live)
            if line is None:
                return last
            choice = line.strip().lower()
            if choice in {"q", "quit"}:
                stdout.write("OK: quit\n")
                stdout.flush()
                return 0
            if choice == "":
                continue
            if choice in {"3", "reset"}:
                confirmed = _confirm_reset(session, stdin, stdout)
                if confirmed is None:
                    return last
                if confirmed == "quit":
                    stdout.write("OK: quit\n")
                    stdout.flush()
                    return 0
                if confirmed is False:
                    continue
            last = dispatch(choice, session, stdout)
    except KeyboardInterrupt:
        stdout.write("\nOK: quit\n")
        stdout.flush()
        return 0


def dispatch(choice: str, session: dict[str, Any], stdout: TextIO) -> int:
    try:
        problem = str(session["problem"])
        lang = str(session["lang"])
        unlocked = int(session["unlocked"])
        if choice in {"1", "run", "test"}:
            return _run_work(problem, lang, unlock=False)
        if choice in {"2", "submit"}:
            stdout.write("NOTE: local submit. Nothing is sent.\n")
            stdout.flush()
            return _run_work(problem, lang, unlock=True)
        if choice in {"3", "reset"}:
            work = ensure_work_copy(problem, lang, reset=True, level=unlocked)
            stdout.write(f"OK: reset\n{work_line(work)}\n")
            stdout.flush()
            return 0
        if choice in {"4", "spec"}:
            return _print_spec(problem, unlocked, stdout)
        if choice in {"5", "vscode", "code"}:
            ensure_work_copy(problem, lang, reset=False, level=unlocked)
            path = write_workspace(problem, lang, unlocked)
            stdout.write(f"WORKSPACE: {file_link(path)}\n")
            spec = _spec_output(problem, lang)
            if spec is not None:
                stdout.write(spec + "\n")
            tests = _tests_output(problem, lang)
            if tests is not None:
                stdout.write(tests + "\n")
            stdout.flush()
            return open_vscode(path)
        stdout.write(f"FAIL: unknown option {choice!r}\n")
        stdout.flush()
        return 1
    except (KeyError, ValueError, FileNotFoundError, OSError) as exc:
        stdout.write(f"FAIL: {exc}\n")
        stdout.flush()
        return 1


def _tests_output(problem: str, lang: str) -> str | None:
    path = public_test_file(problem, lang)
    if path is None:
        return None
    return f"TESTS: {file_link(path)}"


def _spec_output(problem: str, lang: str) -> str | None:
    root = workspace_dir(problem, lang) / "public"
    current = root / "spec" / "current.md"
    if current.is_file():
        return f"SPEC: {file_link(current)}"
    public_spec = root / "spec.md"
    if public_spec.is_file():
        return f"SPEC: {file_link(public_spec)}"
    return None


def _print_tests(problem: str, lang: str) -> None:
    line = _tests_output(problem, lang)
    if line is not None:
        print(line)


def _print_spec_link(problem: str, lang: str) -> None:
    line = _spec_output(problem, lang)
    if line is not None:
        print(line)


def _print_fail(exc: BaseException) -> None:
    print(f"FAIL: {exc}")
    if str(exc).startswith("no runner for "):
        print(start_next())


def _confirm_reset(session: dict[str, Any], stdin: TextIO, stdout: TextIO) -> bool | str | None:
    stdout.write("Type yes to wipe the work file.\n")
    left = remaining_s(int(session["started_at"]), int(session["minutes"]))
    if left == 0:
        stdout.write("NEXT: quit then start starts a new clock and keeps work.\n")
    stdout.flush()
    line = stdin.readline()
    if line == "":
        return None
    confirm = line.strip().lower()
    if confirm == "yes":
        return True
    if confirm in {"q", "quit"}:
        return "quit"
    return False


def _load_or_start(args: argparse.Namespace) -> dict[str, Any]:
    problem = getattr(args, "problem", None)
    lang = getattr(args, "lang", None)
    if (problem is None) != (lang is None):
        raise ValueError("console needs both problem and lang, or neither")
    if problem is None:
        session = load_session()
        if session is None:
            raise ValueError(f"no session. Start with: {invocation()} start bank_system java")
        minutes = int(session["minutes"])
        session = ensure_session(str(session["problem"]), str(session["lang"]), minutes=minutes)
    else:
        row = language(str(lang))
        if row["id"] not in _RUNNERS:
            raise ValueError(f"no runner for {row['id']}")
        minutes = int(getattr(args, "minutes", 90) or 90)
        session = ensure_session(str(problem), row["id"], minutes=minutes, reset=False)
    note_clock_restarted(session)
    return session


def _run_work(problem: str, lang: str, *, unlock: bool) -> int:
    from honepad.cli import cmd_run

    return int(
        cmd_run(
            argparse.Namespace(
                problem=problem,
                lang=lang,
                level=None,
                kind="work",
                unlock=unlock,
            )
        )
    )


def _print_spec(problem: str, level: int, stdout: TextIO) -> int:
    spec = problem_dir(problem) / "spec" / f"level{level}.md"
    if not spec.is_file():
        stdout.write(f"FAIL: missing spec {spec}\n")
        stdout.flush()
        return 1
    text = spec.read_text(encoding="utf-8")
    stdout.write(text if text.endswith("\n") else text + "\n")
    stdout.flush()
    return 0


def _use_live(stdin: TextIO, stdout: TextIO) -> bool:
    if sys.platform == "win32":
        return False
    return bool(stdin.isatty() and stdout.isatty())


@contextmanager
def _keys_now(stdin: TextIO) -> Iterator[None]:
    if sys.platform == "win32":
        yield
        return
    try:
        fd = stdin.fileno()
    except (AttributeError, OSError):
        yield
        return
    try:
        import termios
        import tty
    except ImportError:
        yield
        return
    try:
        old = termios.tcgetattr(fd)
    except termios.error:
        yield
        return
    try:
        tty.setcbreak(fd)
        new = termios.tcgetattr(fd)
        new[3] &= ~termios.ECHO
        termios.tcsetattr(fd, termios.TCSADRAIN, new)
        yield
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def _drain_escape(stdin: TextIO) -> None:
    while True:
        ready, _, _ = select.select([stdin], [], [], 0.02)
        if not ready:
            return
        if stdin.read(1) == "":
            return


def _read_choice(
    session: dict[str, Any],
    stdin: TextIO,
    stdout: TextIO,
    *,
    live: bool,
    clock_fn: Callable[[], int] | None = None,
) -> str | None:
    def _clock() -> str:
        if clock_fn is not None:
            left = clock_fn()
        else:
            left = remaining_s(int(session["started_at"]), int(session["minutes"]))
        return format_clock(left)

    if not live:
        stdout.write(f"[{_clock()}] {_MENU}  > ")
        stdout.flush()
        line = stdin.readline()
        return None if line == "" else line
    with _keys_now(stdin):
        while True:
            stdout.write(f"\r[{_clock()}] {_MENU}")
            stdout.flush()
            ready, _, _ = select.select([stdin], [], [], 1.0)
            if ready:
                ch = stdin.read(1)
                if ch == "":
                    return None
                if ch in {"\n", "\r"}:
                    stdout.write("\n")
                    stdout.flush()
                    return ""
                if ch == "\x1b":
                    _drain_escape(stdin)
                    continue
                stdout.write("\n")
                stdout.flush()
                return ch
            session_now = load_session()
            if session_now is not None:
                session.update(session_now)
