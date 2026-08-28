"""CLI: langs, start, run, timer."""

from __future__ import annotations

import argparse
import json
import sys
import time
from typing import Any

from honepad.catalog import language, languages, problems
from honepad.runner import _RUNNERS, run
from honepad.session import (
    ensure_session,
    ensure_work_copy,
    load_session,
    remaining_s,
    unlock_next,
    work_src,
)
from honepad.traces import load_cases, method_name, problem_dir


def cmd_langs(_args: argparse.Namespace) -> int:
    rows = languages()
    print(f"{len(rows)} languages runner={len(_RUNNERS)}")
    for row in rows:
        suites = ",".join(row["suites"])
        ci = "ci" if row.get("ci") else "no-ci"
        mark = "runner" if row["id"] in _RUNNERS else "no-runner"
        print(f"{row['id']:16} {row['name']:22} {suites:20} {ci:12} {mark:12}")
    return 0


def cmd_start(args: argparse.Namespace) -> int:
    try:
        row = language(args.lang)
        if row["id"] not in _RUNNERS:
            print(f"FAIL: runner for {row['id']} is a factory job (adapter={row.get('adapter')})")
            return 1
        session = ensure_session(args.problem, args.lang, minutes=args.minutes, reset=args.reset)
        unlocked = int(session["unlocked"])
        work = ensure_work_copy(args.problem, row["id"], reset=args.reset, level=unlocked)
        level = unlocked if args.level is None else args.level
        minutes = int(session["minutes"])
        started_at = int(session["started_at"])
    except (KeyError, ValueError, FileNotFoundError, OSError) as exc:
        print(f"FAIL: {exc}")
        return 1
    if level > unlocked:
        print(f"LOCKED: level {level} (unlocked={unlocked})")
        print(f"WORK: {work}")
        return 1
    spec = problem_dir(args.problem) / "spec" / f"level{level}.md"
    if not spec.is_file():
        print(f"FAIL: missing spec {spec}")
        return 1
    print(spec.read_text(encoding="utf-8"))
    print(f"\nWORK: {work}")
    print(
        f"NOTE: {minutes} minutes measures how far you get. "
        "You are not expected to finish every level."
    )
    left = remaining_s(started_at, minutes)
    print(f"OK: unlocked={unlocked} remaining_s={left}")
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
        print(f"FAIL: {exc}")
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
            f"FAIL {fail.case} call[{fail.index}] {shown}({argv}) "
            f"expected={fail.expected!r} actual={fail.actual!r}"
        )
        if kind == "work":
            print(f"WORK: {work_src(args.problem, lang)}")
        return 1
    if report.passed == 0:
        print("FAIL: no cases")
        return 1
    print("OK")
    if practice and session is not None and kind in ("solution", "work") and left > 0:
        nxt = unlock_next(session)
        if nxt is not None:
            print(f"UNLOCKED: level {nxt}")
            ensure_work_copy(args.problem, lang, reset=False, level=nxt)
    return 0


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
        print(f"FAIL: {exc}")
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
        print(f"FAIL: {exc}")
        return 1
    print(json.dumps({"problem": args.problem, "count": len(cases)}, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="honepad")
    sub = p.add_subparsers(dest="cmd", required=True)

    langs = sub.add_parser("langs", help="list catalog")
    langs.set_defaults(func=cmd_langs)

    start = sub.add_parser(
        "start",
        help="print a level spec",
        description=("Print a level spec. Unimplemented catalog langs print FAIL and exit 1."),
    )
    start.add_argument("problem", choices=problems())
    start.add_argument("lang")
    start.add_argument("--level", type=int, default=None)
    start.add_argument("--minutes", type=int, default=90)
    start.add_argument("--reset", action="store_true")
    start.set_defaults(func=cmd_start)

    run_p = sub.add_parser(
        "run",
        help="replay traces",
        description=("Replay traces. Unimplemented catalog langs print FAIL and exit 1."),
    )
    run_p.add_argument("problem", choices=problems())
    run_p.add_argument("--lang", default=None)
    run_p.add_argument("--level", type=int, default=None)
    run_p.add_argument("--kind", choices=("solution", "stub", "work"), default=None)
    run_p.set_defaults(func=cmd_run)

    timer = sub.add_parser("timer", help="print a 90-minute remaining_s")
    timer.add_argument("--minutes", type=int, default=90)
    timer.set_defaults(func=cmd_timer)

    cases = sub.add_parser("cases", help="count traces")
    cases.add_argument("problem", choices=problems())
    cases.add_argument("--level", type=int, default=4)
    cases.set_defaults(func=cmd_cases)
    return p


def main(argv: list[str] | None = None) -> int:
    args: Any = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
