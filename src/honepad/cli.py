"""CLI: langs, start, run, timer."""

from __future__ import annotations

import argparse
import json
import sys
import time
from typing import Any

from honepad.catalog import language, languages, problems
from honepad.runner import run
from honepad.session import (
    ensure_session,
    load_session,
    remaining_s,
    unlock_next,
)
from honepad.traces import load_cases, problem_dir


def cmd_langs(_args: argparse.Namespace) -> int:
    rows = languages()
    print(f"{len(rows)} languages")
    for row in rows:
        suites = ",".join(row["suites"])
        ci = "ci" if row.get("ci") else "no-ci"
        print(f"{row['id']:16} {row['name']:22} {suites:20} {ci}")
    return 0


def cmd_start(args: argparse.Namespace) -> int:
    session = ensure_session(args.problem, args.lang, minutes=args.minutes, reset=args.reset)
    unlocked = int(session["unlocked"])
    level = unlocked if args.level is None else args.level
    if level > unlocked:
        print(f"LOCKED: level {level} (unlocked={unlocked})")
        return 1
    spec = problem_dir(args.problem) / "spec" / f"level{level}.md"
    if not spec.is_file():
        print(f"FAIL: missing spec {spec}")
        return 1
    print(spec.read_text(encoding="utf-8"))
    row = language(args.lang)
    stub = (
        problem_dir(args.problem).parent.parent
        / "langs"
        / row["id"]
        / "problems"
        / args.problem
        / f"stub.{row['ext']}"
    )
    print(f"\nSTUB: {stub}")
    left = remaining_s(int(session["started_at"]), int(session["minutes"]))
    print(f"OK: unlocked={unlocked} remaining_s={left}")
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    session = load_session()
    same = session is not None and session.get("problem") == args.problem
    lang = args.lang or (str(session["lang"]) if same and session is not None else "python3")
    practice = args.level is None and same and session is not None
    if args.level is None:
        level = int(session["unlocked"]) if practice and session is not None else 4
    else:
        level = args.level
    report = run(args.problem, lang, level, kind=args.kind)
    print(f"{report.problem} {report.lang} level<={report.level} passed={report.passed}")
    if report.failed:
        fail = report.failed[0]
        print(
            f"FAIL {fail.case} call[{fail.index}] {fail.method}{tuple(fail.args)} "
            f"expected={fail.expected!r} actual={fail.actual!r}"
        )
        return 1
    print("OK")
    if practice and session is not None and args.kind == "solution":
        nxt = unlock_next(session)
        if nxt is not None:
            print(f"UNLOCKED: level {nxt}")
    return 0


def cmd_timer(args: argparse.Namespace) -> int:
    # Agent-driven: print remaining, do not sleep the session.
    session = load_session()
    if session is not None:
        minutes = int(session["minutes"])
        started = int(session["started_at"])
        left = remaining_s(started, minutes)
        print(f"WAIT: timer {minutes}m remaining_s={left}")
        print(f"OK: started_at={started}")
    else:
        remaining = args.minutes * 60
        print(f"WAIT: timer {args.minutes}m remaining_s={remaining}")
        print(f"OK: started_at={int(time.time())}")
    print("NEXT: re-check remaining_s later; do not sleep inside this process")
    return 0


def cmd_cases(args: argparse.Namespace) -> int:
    cases = load_cases(args.problem, args.level)
    print(json.dumps({"problem": args.problem, "count": len(cases)}, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="honepad")
    sub = p.add_subparsers(dest="cmd", required=True)

    langs = sub.add_parser("langs", help="list catalog")
    langs.set_defaults(func=cmd_langs)

    start = sub.add_parser("start", help="print a level spec")
    start.add_argument("problem", choices=problems())
    start.add_argument("lang")
    start.add_argument("--level", type=int, default=None)
    start.add_argument("--minutes", type=int, default=90)
    start.add_argument("--reset", action="store_true")
    start.set_defaults(func=cmd_start)

    run_p = sub.add_parser("run", help="replay traces")
    run_p.add_argument("problem", choices=problems())
    run_p.add_argument("--lang", default=None)
    run_p.add_argument("--level", type=int, default=None)
    run_p.add_argument("--kind", choices=("solution", "stub"), default="solution")
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
