"""Live practice console: numbered menu, remaining_s clock, vscode."""

from __future__ import annotations

import argparse
import select
import sys
from collections.abc import Callable
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
from honepad.term import file_link, format_clock, work_line
from honepad.traces import problem_dir
from honepad.workspace import open_vscode, public_test_file, write_workspace

_MENU = "1 run  2 submit (local)  3 reset  4 spec  5 vscode  q quit"


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
        print(f"FAIL: {exc}")
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
        _print_tests(str(session["problem"]), str(session["lang"]))
        if args.no_open:
            print("OK: wrote workspace")
            return 0
        return open_vscode(path)
    except (KeyError, ValueError, FileNotFoundError, OSError) as exc:
        print(f"FAIL: {exc}")
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
            return _run_work(problem, lang)
        if choice in {"2", "submit"}:
            stdout.write("NOTE: local submit. Nothing is sent.\n")
            stdout.flush()
            return _run_work(problem, lang)
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


def _print_tests(problem: str, lang: str) -> None:
    line = _tests_output(problem, lang)
    if line is not None:
        print(line)


def _load_or_start(args: argparse.Namespace) -> dict[str, Any]:
    problem = getattr(args, "problem", None)
    lang = getattr(args, "lang", None)
    if (problem is None) != (lang is None):
        raise ValueError("console needs both problem and lang, or neither")
    if problem is None:
        session = load_session()
        if session is None:
            raise ValueError("no session. Start with: honepad start bank_system java")
        minutes = int(session["minutes"])
        session = ensure_session(str(session["problem"]), str(session["lang"]), minutes=minutes)
    else:
        row = language(str(lang))
        if row["id"] not in _RUNNERS:
            raise ValueError(
                f"runner for {row['id']} is a factory job (adapter={row.get('adapter')})"
            )
        minutes = int(getattr(args, "minutes", 90) or 90)
        session = ensure_session(str(problem), row["id"], minutes=minutes, reset=False)
    note_clock_restarted(session)
    return session


def _run_work(problem: str, lang: str) -> int:
    from honepad.cli import cmd_run

    return int(cmd_run(argparse.Namespace(problem=problem, lang=lang, level=None, kind="work")))


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
    while True:
        stdout.write(f"\r[{_clock()}] {_MENU}  > ")
        stdout.flush()
        ready, _, _ = select.select([stdin], [], [], 1.0)
        if ready:
            line = stdin.readline()
            stdout.write("\n")
            stdout.flush()
            return None if line == "" else line
        session_now = load_session()
        if session_now is not None:
            session.update(session_now)
