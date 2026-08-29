"""CLI: langs, start, run, timer, console, vscode."""

from __future__ import annotations

import argparse
import json
import sys
import time
from typing import Any

from honepad.catalog import language, languages, problems
from honepad.console import cmd_console, cmd_vscode, loop_console
from honepad.runner import _RUNNERS, run
from honepad.session import (
    ensure_session,
    ensure_work_copy,
    load_session,
    max_level,
    note_clock_restarted,
    remaining_s,
    unlock_next,
    work_src,
)
from honepad.term import (
    file_link,
    start_next,
    status_fail,
    status_note,
    status_ok,
    status_unlock,
    work_line,
)
from honepad.traces import load_cases, method_name, problem_dir
from honepad.workspace import write_workspace


def cmd_langs(_args: argparse.Namespace) -> int:
    rows = languages()
    print(f"{len(rows)} languages runner={len(_RUNNERS)}")
    for row in rows:
        suites = ",".join(row["suites"])
        ci = "ci" if row.get("ci") else "no-ci"
        mark = "runner" if row["id"] in _RUNNERS else "no-runner"
        print(f"{row['id']:16} {row['name']:22} {suites:20} {ci:12} {mark:12}")
    return 0


def cmd_default(_args: argparse.Namespace) -> int:
    try:
        session = load_session()
    except ValueError as exc:
        print(status_fail(f"FAIL: {exc}"))
        return 1
    if session is None:
        _print_start_usage()
        return 1
    return cmd_console(argparse.Namespace(problem=None, lang=None, minutes=90))


def _print_start_usage() -> None:
    print(status_fail("FAIL: no session"))
    print(start_next())
    print("problems: " + ", ".join(problems()))


def cmd_start(args: argparse.Namespace) -> int:
    if not args.problem or not args.lang:
        print(status_fail("FAIL: start needs a problem and a language"))
        print(start_next())
        print("problems: " + ", ".join(problems()))
        return 1
    try:
        row = language(args.lang)
        if row["id"] not in _RUNNERS:
            print(status_fail(f"FAIL: no runner for {row['id']}"))
            print(start_next())
            return 1
        session = ensure_session(args.problem, args.lang, minutes=args.minutes, reset=args.reset)
        unlocked = int(session["unlocked"])
        work = ensure_work_copy(args.problem, row["id"], reset=args.reset, level=unlocked)
        level = unlocked if args.level is None else args.level
        minutes = int(session["minutes"])
        started_at = int(session["started_at"])
    except (KeyError, ValueError, FileNotFoundError, OSError) as exc:
        print(status_fail(f"FAIL: {exc}"))
        return 1
    if level > unlocked:
        print(status_fail(f"LOCKED: level {level} (unlocked={unlocked})"))
        print(work_line(work))
        return 1
    spec = problem_dir(args.problem) / "spec" / f"level{level}.md"
    if not spec.is_file():
        print(status_fail(f"FAIL: missing spec {spec}"))
        return 1
    print(spec.read_text(encoding="utf-8"))
    print(f"\n{work_line(work)}")
    side = work.parent / "spec.md"
    if side.is_file():
        print(f"SPEC: {file_link(side)}")
    print(
        f"NOTE: {minutes} minutes measures how far you get. "
        "You are not expected to finish every level."
    )
    print(status_note("NOTE: honepad console opens a live menu (run, submit, reset, vscode)."))
    note_clock_restarted(session)
    left = remaining_s(started_at, minutes)
    print(status_ok(f"OK: unlocked={unlocked} remaining_s={left}"))
    if not getattr(args, "no_console", False) and sys.stdin.isatty() and sys.stdout.isatty():
        return loop_console(session, stdin=sys.stdin, stdout=sys.stdout)
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    try:
        session = load_session()
        lang = args.lang or (
            str(session["lang"])
            if session is not None and session.get("problem") == args.problem
            else "python3"
        )
        same = (
            session is not None
            and session.get("problem") == args.problem
            and str(session.get("lang")) == lang
        )
        practice = args.level is None and same
        if args.level is None:
            level = int(session["unlocked"]) if practice and session is not None else 4
        else:
            level = args.level
        kind = args.kind
        if kind is None:
            kind = "work" if same and session is not None else "solution"
        left = 0
        if session is not None and same:
            left = remaining_s(int(session["started_at"]), int(session["minutes"]))
            print(f"remaining_s={left}")
        report = run(args.problem, lang, level, kind=kind)
    except (
        NotImplementedError,
        KeyError,
        FileNotFoundError,
        OSError,
        RuntimeError,
        ValueError,
    ) as exc:
        print(status_fail(f"FAIL: {exc}"))
        return 1
    summary = f"{report.problem} {report.lang} level<={report.level} passed={report.passed}"
    if session is not None and same:
        summary = f"{summary} remaining_s={left}"
    print(summary)
    if report.failed:
        fail = report.failed[0]
        naming = str(language(lang)["naming"])
        shown = method_name(fail.method, naming)
        argv = ", ".join(repr(item) for item in fail.args)
        print(
            status_fail(
                f"FAIL {fail.case} call[{fail.index}] {shown}({argv}) "
                f"expected={fail.expected!r} actual={fail.actual!r}"
            )
        )
        if kind == "work":
            print(work_line(work_src(args.problem, lang)))
        return 1
    if report.passed == 0:
        print(status_fail("FAIL: no cases"))
        return 1
    print(status_ok("OK"))
    may_unlock = bool(getattr(args, "unlock", False))
    if practice and session is not None and kind in ("solution", "work"):
        nxt = int(session["unlocked"]) + 1
        if nxt > max_level(str(session["problem"])):
            return 0
        if left == 0:
            print(status_fail("TIME UP: remaining_s=0. Next level stays locked."))
            print(status_note("NOTE: honepad start starts a new clock and keeps your work."))
            return 0
        if may_unlock:
            unlocked = unlock_next(session)
            if unlocked is not None:
                print(status_unlock(f"UNLOCKED: level {unlocked}"))
                ensure_work_copy(args.problem, lang, reset=False, level=unlocked)
                spec = problem_dir(args.problem) / "spec" / f"level{unlocked}.md"
                if spec.is_file():
                    print(spec.read_text(encoding="utf-8").rstrip() + "\n")
                write_workspace(args.problem, lang, unlocked)
        else:
            print(
                status_note(
                    f"NOTE: still unlocked={session['unlocked']}. 2 submit unlocks the next level."
                )
            )
    return 0


def cmd_submit(args: argparse.Namespace) -> int:
    args.unlock = True
    return cmd_run(args)


def cmd_timer(args: argparse.Namespace) -> int:
    # Agent-driven: print remaining, do not sleep the session.
    try:
        session = load_session()
        if session is not None:
            minutes = int(session["minutes"])
            started = int(session["started_at"])
        else:
            minutes = args.minutes
            started = int(time.time())
    except ValueError as exc:
        print(status_fail(f"FAIL: {exc}"))
        return 1
    if session is not None:
        left = remaining_s(started, minutes)
        print(f"WAIT: timer {minutes}m remaining_s={left}")
        print(f"OK: started_at={started}")
    else:
        remaining = minutes * 60
        print(f"WAIT: timer {minutes}m remaining_s={remaining}")
        print(f"OK: started_at={started}")
    print("NEXT: re-check remaining_s later; do not sleep inside this process")
    return 0


def cmd_cases(args: argparse.Namespace) -> int:
    try:
        cases = load_cases(args.problem, args.level)
    except (ValueError, KeyError, FileNotFoundError) as exc:
        print(status_fail(f"FAIL: {exc}"))
        return 1
    print(json.dumps({"problem": args.problem, "count": len(cases)}, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="honepad")
    p.set_defaults(func=cmd_default)
    sub = p.add_subparsers(dest="cmd", required=False)

    langs = sub.add_parser("langs", help="list catalog")
    langs.set_defaults(func=cmd_langs)

    start = sub.add_parser(
        "start",
        help="start a 90-minute session",
        description=(
            "Start a practice session: spec, work file, 90-minute clock. "
            "On a TTY this opens the live menu. "
            "Unimplemented catalog langs print FAIL and exit 1."
        ),
    )
    start.add_argument("problem", nargs="?", choices=problems())
    start.add_argument("lang", nargs="?")
    start.add_argument("--level", type=int, default=None)
    start.add_argument("--minutes", type=int, default=90)
    start.add_argument("--reset", action="store_true")
    start.add_argument("--no-console", action="store_true")
    start.set_defaults(func=cmd_start)

    run_p = sub.add_parser(
        "run",
        help="replay traces",
        description=(
            "Replay traces without unlocking. "
            "Use submit or run --submit to unlock after a passing practice run. "
            "Unimplemented catalog langs print FAIL and exit 1."
        ),
    )
    run_p.add_argument("problem", choices=problems())
    run_p.add_argument("--lang", default=None)
    run_p.add_argument("--level", type=int, default=None)
    run_p.add_argument("--kind", choices=("solution", "stub", "work"), default=None)
    run_p.add_argument(
        "--submit",
        action="store_true",
        dest="unlock",
        help="unlock the next level after a passing practice run",
    )
    run_p.set_defaults(func=cmd_run, unlock=False)

    submit = sub.add_parser(
        "submit",
        help="replay traces and unlock on pass",
        description=(
            "Local submit: replay traces, then unlock the next level on pass. "
            "Nothing is sent. Unimplemented catalog langs print FAIL and exit 1."
        ),
    )
    submit.add_argument("problem", choices=problems())
    submit.add_argument("--lang", default=None)
    submit.add_argument("--level", type=int, default=None)
    submit.add_argument("--kind", choices=("solution", "stub", "work"), default=None)
    submit.set_defaults(func=cmd_submit, unlock=True)

    timer = sub.add_parser("timer", help="print a 90-minute remaining_s")
    timer.add_argument("--minutes", type=int, default=90)
    timer.set_defaults(func=cmd_timer)

    cases = sub.add_parser("cases", help="count traces")
    cases.add_argument("problem", choices=problems())
    cases.add_argument("--level", type=int, default=4)
    cases.set_defaults(func=cmd_cases)

    console = sub.add_parser(
        "console",
        help="live practice menu",
        description=(
            "Live menu with remaining_s clock. On a TTY, keys 1-5 and q "
            "run immediately (no Enter). 1 run tests without unlocking, "
            "2 submit (local) unlocks the next level, "
            "3 reset work, 4 spec, 5 vscode workspace. Paths use OSC 8 file:// links."
        ),
    )
    console.add_argument("problem", nargs="?", choices=problems())
    console.add_argument("lang", nargs="?")
    console.add_argument("--minutes", type=int, default=90)
    console.set_defaults(func=cmd_console)

    vscode = sub.add_parser(
        "vscode",
        help="open work plus public tests in VS Code",
        description=(
            "Write a VS Code workspace with the work file and unlocked public traces, "
            "then open it with `code` when on PATH."
        ),
    )
    vscode.add_argument("problem", nargs="?", choices=problems())
    vscode.add_argument("lang", nargs="?")
    vscode.add_argument("--minutes", type=int, default=90)
    vscode.add_argument("--no-open", action="store_true")
    vscode.set_defaults(func=cmd_vscode)
    return p


def main(argv: list[str] | None = None) -> int:
    args: Any = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
