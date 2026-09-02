"""CLI: langs, start, run, timer, console, vscode."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from typing import Any

from honepad.catalog import language, language_ids, languages, problems, suggest_choice
from honepad.console import cmd_console, cmd_vscode, loop_console
from honepad.runner import _RUNNERS, run
from honepad.session import (
    drop_level,
    ensure_session,
    ensure_work_copy,
    load_session,
    max_level,
    note_clock_restarted,
    remaining_s,
    require_minutes,
    unlock_next,
    work_src,
)
from honepad.term import (
    invocation,
    paint_spec,
    print_complete,
    print_fail,
    spec_line,
    start_next,
    status_fail,
    status_note,
    status_ok,
    status_unlock,
    work_line,
    work_reset_next,
)
from honepad.traces import load_cases, method_name, problem_dir
from honepad.workspace import workspace_dir, write_workspace


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
        print_fail(exc)
        return 1
    if session is None:
        if _can_prompt():
            return cmd_start(
                argparse.Namespace(
                    problem=None,
                    lang=None,
                    level=None,
                    minutes=None,
                    reset=False,
                    back=False,
                    no_console=False,
                )
            )
        _print_start_usage()
        return 1
    return cmd_console(argparse.Namespace(problem=None, lang=None, minutes=None))


def _print_start_usage() -> None:
    print(status_fail("FAIL: no session"))
    print(start_next())
    print("problems: " + ", ".join(problems()))


def _can_prompt() -> bool:
    try:
        return bool(sys.stdin.isatty() and sys.stdout.isatty())
    except AttributeError:
        return False


def _runner_ids() -> list[str]:
    return [row["id"] for row in languages() if row["id"] in _RUNNERS]


def _print_choices(title: str, items: list[str]) -> None:
    print(f"{title}:")
    width = len(str(len(items)))
    for i, item in enumerate(items, 1):
        print(f"  {i:>{width}}  {item}")
    sys.stdout.flush()


def _read_choice(items: list[str]) -> str | None:
    while True:
        line = sys.stdin.readline()
        if line == "":
            return None
        raw = line.strip()
        if raw in {"", "q", "quit"}:
            return None
        if raw.isdigit():
            n = int(raw)
            if 1 <= n <= len(items):
                return items[n - 1]
        elif raw in items:
            return raw
        print(status_fail(f"FAIL: not a choice: {raw}"))
        hint = suggest_choice(raw, items)
        if hint is not None:
            print(f"Did you mean {hint}?")
        sys.stdout.flush()


def _fill_start_args(args: argparse.Namespace) -> bool:
    if not args.lang:
        ids = _runner_ids()
        _print_choices("language", ids)
        picked = _read_choice(ids)
        if picked is None:
            return False
        args.lang = picked
    if not args.problem:
        opts = problems()
        _print_choices("problem", opts)
        picked = _read_choice(opts)
        if picked is None:
            return False
        args.problem = picked
    return True


def _is_work_file_problem(exc: BaseException) -> bool:
    text = str(exc)
    return "work file" in text or "/work/" in text or "work." in text


def _print_fail(exc: BaseException) -> None:
    print_fail(exc)


def _check_level(problem: str, level: int) -> None:
    top = max_level(problem)
    if level < 1 or level > top:
        raise ValueError(f"{problem} has levels 1..{top}")


def _require_problem(problem: str) -> None:
    if problem not in problems():
        raise ValueError(f"invalid problem: {problem}")


def _is_lang_token(name: str) -> bool:
    return name in _RUNNERS or name in language_ids()


def require_java_path(lang_id: str) -> None:
    if lang_id != "java":
        return
    missing = next(
        (name for name in ("javac", "java") if shutil.which(name) is None),
        None,
    )
    if missing is not None:
        raise RuntimeError(f"{missing} not on PATH")


def _swap_start_lang_problem(args: argparse.Namespace) -> None:
    if not args.problem or not args.lang:
        return
    if _is_lang_token(args.problem) and args.lang in problems() and not _is_lang_token(args.lang):
        args.problem, args.lang = args.lang, args.problem


def cmd_start(args: argparse.Namespace) -> int:
    if (
        args.problem
        and not args.lang
        and args.problem not in problems()
        and _is_lang_token(args.problem)
    ):
        args.lang = args.problem
        args.problem = None
    _swap_start_lang_problem(args)
    if not args.problem or not args.lang:
        if not (_can_prompt() and _fill_start_args(args)):
            if args.lang and not args.problem:
                print(status_fail("FAIL: start needs a problem"))
                print(f"NEXT: {invocation()} start bank_system {args.lang}")
            else:
                print(status_fail("FAIL: start needs a problem and a language"))
                print(start_next())
            print("problems: " + ", ".join(problems()))
            return 1
    try:
        try:
            row = language(args.lang)
        except ValueError:
            if (
                args.problem
                and _is_lang_token(args.problem)
                and args.lang in problems()
                and not _is_lang_token(args.lang)
            ):
                args.problem, args.lang = args.lang, args.problem
                row = language(args.lang)
            else:
                raise
        if row["id"] not in _RUNNERS:
            print(status_fail(f"FAIL: no runner for {row['id']}"))
            print(start_next())
            return 1
        if args.reset and getattr(args, "back", False):
            print(status_fail("FAIL: use --reset or --back, not both"))
            print(f"NEXT: {invocation()} start --reset")
            return 1
        _require_problem(args.problem)
        if args.level is not None:
            _check_level(args.problem, args.level)
        require_java_path(row["id"])
        if getattr(args, "back", False):
            session = load_session()
            if session is None:
                print(status_fail("FAIL: no session to go back"))
                print(start_next())
                return 1
            if session["problem"] != args.problem or str(session["lang"]) != row["id"]:
                print(status_fail("FAIL: --back needs the current problem and language"))
                print(f"NEXT: {invocation()} start {session['problem']} {session['lang']} --back")
                return 1
            unlocked = int(session["unlocked"])
            if unlocked <= 1:
                print(status_fail("FAIL: already level 1"))
                print(work_line(work_src(args.problem, row["id"])))
                print(f"NEXT: {invocation()} start")
                return 1
            session, work = drop_level(session, minutes=args.minutes)
            unlocked = int(session["unlocked"])
        else:
            session = ensure_session(
                args.problem, args.lang, minutes=args.minutes, reset=args.reset
            )
            unlocked = int(session["unlocked"])
            work = ensure_work_copy(args.problem, row["id"], reset=args.reset, level=unlocked)
            if args.reset and workspace_dir(args.problem, row["id"]).exists():
                write_workspace(args.problem, row["id"], unlocked)
        level = unlocked if args.level is None else args.level
        minutes = int(session["minutes"])
        started_at = int(session["started_at"])
    except (KeyError, ValueError, FileNotFoundError, OSError, RuntimeError) as exc:
        _print_fail(exc)
        return 1
    if level > unlocked:
        print(status_fail(f"LOCKED: LEVEL {level} (open through LEVEL {unlocked})"))
        print(work_line(work))
        return 1
    spec = problem_dir(args.problem) / "spec" / f"level{level}.md"
    if not spec.is_file():
        print(status_fail(f"FAIL: missing spec {spec}"))
        return 1
    left = remaining_s(started_at, minutes)
    if unlocked > 1 or session.get("clock_restarted"):
        print(
            status_note(
                f"NOTE: resume at LEVEL {unlocked}. "
                "start --reset is L1. start --back or console 3 drops a level."
            )
        )
    note_clock_restarted(session)
    print(work_line(work))
    side = work.parent / "spec.md"
    if side.is_file():
        print(spec_line(side))
    print(
        f"NOTE: {minutes} minutes measures how far you get. "
        "You are not expected to finish every level."
    )
    print(status_note("NOTE: honepad console opens a live menu (run, submit, reset, vscode)."))
    print(status_ok(f"OK: LEVEL {unlocked} remaining_s={left}"))
    print(paint_spec(spec.read_text(encoding="utf-8")))
    if not getattr(args, "no_console", False) and _can_prompt():
        return loop_console(session, stdin=sys.stdin, stdout=sys.stdout)
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    try:
        _require_problem(args.problem)
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
        if getattr(args, "unlock", False) and not same:
            print(status_fail("FAIL: no session"))
            print(f"NEXT: {invocation()} start {args.problem} {lang}")
            return 1
        unlocked_now = int(session["unlocked"]) if same and session is not None else None
        practice = same and (args.level is None or args.level == unlocked_now)
        top = max_level(args.problem)
        if args.level is None:
            level = unlocked_now if practice and unlocked_now is not None else top
        else:
            _check_level(args.problem, args.level)
            level = args.level
        kind = args.kind
        if kind is None:
            kind = "work" if same and session is not None else "solution"
        left = 0
        if session is not None and same:
            left = remaining_s(int(session["started_at"]), int(session["minutes"]))
            print(f"remaining_s={left}")
        report = run(args.problem, lang, level, kind=kind)
        if session is not None and same:
            left = remaining_s(int(session["started_at"]), int(session["minutes"]))
        if report.debug.strip():
            for line in report.debug.splitlines():
                print(f"DEBUG: {line}")
    except (
        NotImplementedError,
        KeyError,
        FileNotFoundError,
        OSError,
        RuntimeError,
        ValueError,
    ) as exc:
        _print_fail(exc)
        if _is_work_file_problem(exc):
            print(work_reset_next())
        return 1
    print(f"{report.problem} {report.lang} through LEVEL {report.level} passed={report.passed}")
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
    may_unlock = bool(getattr(args, "unlock", False))
    if practice and session is not None and kind in ("solution", "work"):
        nxt = int(session["unlocked"]) + 1
        if nxt > max_level(str(session["problem"])):
            print_complete(
                str(session["problem"]),
                str(session["lang"]),
                levels=max_level(str(session["problem"])),
                passed=report.passed,
            )
            return 0
        if left == 0:
            print(status_fail("TIME UP: remaining_s=0. Next level stays locked."))
            print(status_note("NOTE: q then honepad start starts a new clock and keeps your work."))
            return 0
        if may_unlock:
            try:
                ensure_work_copy(args.problem, lang, reset=False, level=nxt, require_merge=True)
            except (KeyError, ValueError, FileNotFoundError, OSError, RuntimeError) as exc:
                print(status_fail(f"FAIL: {exc}"))
                print(work_reset_next())
                return 1
            workspace_exc: BaseException | None = None
            try:
                write_workspace(args.problem, lang, nxt)
            except (KeyError, ValueError, FileNotFoundError, OSError, RuntimeError) as exc:
                workspace_exc = exc
            print(status_ok("OK"))
            unlocked = unlock_next(session)
            if unlocked is not None:
                print(status_unlock(f"UNLOCKED: level {unlocked}"))
                spec = problem_dir(args.problem) / "spec" / f"level{unlocked}.md"
                if spec.is_file():
                    print(paint_spec(spec.read_text(encoding="utf-8")).rstrip() + "\n")
            if workspace_exc is not None:
                print(status_note(f"NOTE: workspace {workspace_exc}"))
            return 0
        print(status_ok("OK"))
        print(
            status_note(
                f"NOTE: still LEVEL {session['unlocked']}. 2 submit unlocks the next level."
            )
        )
        return 0
    print(status_ok("OK"))
    return 0


def cmd_submit(args: argparse.Namespace) -> int:
    try:
        _require_problem(args.problem)
    except ValueError as exc:
        _print_fail(exc)
        return 1
    confirm = getattr(args, "confirm", None)
    if confirm is not None:
        if str(confirm).strip().lower() not in {"y", "yes"}:
            print("OK: submit cancelled")
            return 0
    elif sys.stdin.isatty() and sys.stdout.isatty():
        from honepad.console import _confirm_unlock, _use_live

        ok = _confirm_unlock(sys.stdin, sys.stdout, live=_use_live(sys.stdin, sys.stdout))
        if ok is None:
            return 1
        if not ok:
            print("OK: submit cancelled")
            return 0
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
            minutes = require_minutes(args.minutes)
            started = int(time.time())
    except ValueError as exc:
        print_fail(exc)
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
        _require_problem(args.problem)
        if args.level is None:
            level = max_level(args.problem)
        else:
            _check_level(args.problem, args.level)
            level = args.level
        cases = load_cases(args.problem, level)
    except (ValueError, KeyError, FileNotFoundError) as exc:
        _print_fail(exc)
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
            "On a TTY, omit problem and language to pick from a list, "
            "then this opens the live menu. "
            "--reset starts over at level 1. --back drops one unlocked level. "
            "Unimplemented catalog langs print FAIL and exit 1."
        ),
    )
    start.add_argument("problem", nargs="?")
    start.add_argument("lang", nargs="?")
    start.add_argument("--level", type=int, default=None)
    start.add_argument("--minutes", type=int, default=None)
    start.add_argument("--reset", action="store_true")
    start.add_argument("--back", action="store_true")
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
    run_p.add_argument("problem")
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
    submit.add_argument("problem")
    submit.add_argument("--lang", default=None)
    submit.add_argument("--level", type=int, default=None)
    submit.add_argument("--kind", choices=("solution", "stub", "work"), default=None)
    submit.add_argument(
        "--confirm",
        default=None,
        help="y unlocks after a passing run; n cancels. TTY asks if omitted.",
    )
    submit.set_defaults(func=cmd_submit, unlock=True)

    timer = sub.add_parser("timer", help="print a 90-minute remaining_s")
    timer.add_argument("--minutes", type=int, default=90)
    timer.set_defaults(func=cmd_timer)

    cases = sub.add_parser("cases", help="count traces")
    cases.add_argument("problem")
    cases.add_argument("--level", type=int, default=None)
    cases.set_defaults(func=cmd_cases)

    console = sub.add_parser(
        "console",
        help="live practice menu",
        description=(
            "Live menu with remaining_s clock. On a TTY, keys 1-5 and q "
            "run immediately (no Enter). 1 run tests without unlocking, "
            "2 submit (local) unlocks the next level, "
            "3 reset (yes=this level, back=previous, all=L1), "
            "4 spec, 5 vscode workspace. Paths use OSC 8 file:// links."
        ),
    )
    console.add_argument("problem", nargs="?")
    console.add_argument("lang", nargs="?")
    console.add_argument("--minutes", type=int, default=None)
    console.set_defaults(func=cmd_console)

    vscode = sub.add_parser(
        "vscode",
        help="open work plus public tests in VS Code",
        description=(
            "Write a VS Code workspace with the work file and unlocked public traces, "
            "then open it with `code` when on PATH."
        ),
    )
    vscode.add_argument("problem", nargs="?")
    vscode.add_argument("lang", nargs="?")
    vscode.add_argument("--minutes", type=int, default=None)
    vscode.add_argument("--no-open", action="store_true")
    vscode.set_defaults(func=cmd_vscode)
    return p


def main(argv: list[str] | None = None) -> int:
    args: Any = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
