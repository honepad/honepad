"""Live practice console: numbered menu, countdown clock, vscode."""

from __future__ import annotations

import argparse
import select
import sys
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from typing import Any, TextIO

from honepad.catalog import language, languages, problems, suggest_choice
from honepad.runner import _RUNNERS
from honepad.session import (
    drop_level,
    ensure_session,
    ensure_work_copy,
    extra_work_note,
    load_session,
    max_level,
    note_clock_restarted,
    remaining_s,
    restart_all,
    work_src,
)
from honepad.term import (
    accent,
    bold,
    clock_style,
    columns,
    file_link,
    format_clock,
    gradient,
    invocation,
    level_dots,
    paint_spec,
    print_fail,
    render_help,
    render_keys,
    render_prompt,
    rule,
    spec_line,
    status_fail,
    status_note,
    status_unlock,
    work_line,
)
from honepad.traces import problem_dir
from honepad.workspace import (
    open_vscode,
    public_test_file,
    refresh_workspace,
    workspace_dir,
    write_workspace,
)


def render_banner(session: dict[str, Any], now: int | None = None) -> str:
    problem = str(session["problem"])
    lang = str(session["lang"])
    unlocked = int(session["unlocked"])
    top = max_level(problem)
    left = remaining_s(int(session["started_at"]), int(session["minutes"]), now)
    work = work_src(problem, lang)
    title = gradient("honepad", (94, 234, 212), (56, 189, 248))
    level = accent(f"LEVEL {unlocked}/{top}")
    clock = clock_style(left, format_clock(left))
    dots = level_dots(unlocked, top)
    head = f"{title}  {problem}  {lang}  {level}"
    if dots:
        head = f"{head}  {dots}"
    lines = [
        f"{head}  [{clock}]",
        work_line(work),
        render_keys(last_level=bool(session.get("cleared"))),
    ]
    extra = extra_work_note(problem, lang)
    if extra is not None:
        lines.append(status_note(extra))
    if session.get("cleared"):
        lines.append(status_unlock(f"DONE: {problem} {lang}"))
    elif unlocked >= max_level(problem):
        lines.append(status_note("NOTE: last level. Pass all traces to finish."))
    elif left == 0:
        lines.append(status_fail("TIME UP: submit will not unlock."))
        lines.append(
            status_note("NOTE: a new clock is quit then start (keeps work). 3 deletes the file.")
        )
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
        refresh_workspace(
            str(session["problem"]),
            str(session["lang"]),
            int(session["unlocked"]),
            cleared=bool(session.get("cleared")),
        )
    except (KeyError, ValueError, FileNotFoundError, OSError, RuntimeError) as exc:
        _print_fail(exc)
        if "both problem and lang" in str(exc):
            print(f"NEXT: {invocation()} console bank_system java")
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
            cleared=bool(session.get("cleared")),
        )
        work = work_src(str(session["problem"]), str(session["lang"]))
        print(work_line(work))
        print(f"WORKSPACE: {file_link(path)}")
        _print_spec_link(str(session["problem"]), str(session["lang"]))
        _print_tests(str(session["problem"]), str(session["lang"]))
        if args.no_open:
            print("OK: wrote workspace")
            return 0
        return open_vscode(path, [work])
    except (KeyError, ValueError, FileNotFoundError, OSError, RuntimeError) as exc:
        _print_fail(exc)
        if "both problem and lang" in str(exc):
            print(f"NEXT: {invocation()} vscode bank_system java")
        return 1


def _reload_session(session: dict[str, Any], stdout: TextIO | None = None) -> dict[str, Any]:
    try:
        loaded = load_session()
    except ValueError as exc:
        if stdout is not None:
            stdout.write(status_fail(f"FAIL: {exc}") + "\n")
            stdout.flush()
        return session
    if loaded is None:
        return session
    session.clear()
    session.update(loaded)
    return session


def _banner_key(session: dict[str, Any]) -> tuple[str, str, int, bool]:
    """What the banner shows. A change here is what makes it reprint."""
    return (
        str(session["problem"]),
        str(session["lang"]),
        int(session["unlocked"]),
        bool(session.get("cleared")),
    )


def loop_console(
    session: dict[str, Any],
    *,
    stdin: TextIO,
    stdout: TextIO,
    live: bool | None = None,
) -> int:
    last = 0
    use_live = _use_live(stdin, stdout) if live is None else live
    bannered = False
    shown = _banner_key(session)
    shown_time_up = [False]
    # Latched while the menu is the last thing on screen, so holding Enter
    # reprints it once rather than once per keypress. Any real output below
    # clears it.
    shown_menu = [False]
    try:
        while True:
            session = _reload_session(session, stdout)
            now_key = _banner_key(session)
            if not bannered:
                stdout.write(render_banner(session) + "\n")
                bannered = True
                shown = now_key
                shown_menu[0] = True
            else:
                left = remaining_s(int(session["started_at"]), int(session["minutes"]))
                if left > 0:
                    shown_time_up[0] = False
                if now_key != shown:
                    stdout.write(render_banner(session) + "\n")
                    shown = now_key
                    shown_menu[0] = True
                elif left == 0 and not shown_time_up[0]:
                    stdout.write(render_banner(session) + "\n")
                    shown_time_up[0] = True
                    shown_menu[0] = True
            stdout.flush()
            line = _read_choice(
                session,
                stdin,
                stdout,
                live=use_live,
                shown_time_up=shown_time_up,
                shown_menu=shown_menu,
            )
            if line is None:
                return last
            choice = line.strip().lower()
            if choice in {"q", "quit"}:
                stdout.write("OK: quit\n")
                stdout.flush()
                return 0
            if choice == "":
                continue
            # Every real command writes something, which pushes the menu up
            # the screen. Let the next Enter put it back.
            shown_menu[0] = False
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
                stdout.write("\n")
                try:
                    last = _apply_reset(confirmed, session, stdout)
                except (KeyError, ValueError, FileNotFoundError, OSError, RuntimeError) as exc:
                    stdout.write(status_fail(f"FAIL: {exc}") + "\n")
                    last = 1
                else:
                    bannered = False
                    shown_time_up[0] = False
                stdout.write("\n")
                continue
            if choice in {"2", "submit"}:
                if int(session["unlocked"]) < max_level(str(session["problem"])):
                    unlock = _confirm_unlock(stdin, stdout, live=use_live)
                    if unlock is None:
                        return last
                    if not unlock:
                        stdout.write("OK: submit cancelled\n")
                        stdout.flush()
                        continue
            stdout.write("\n")
            last = dispatch(choice, session, stdout, stdin)
            stdout.write("\n" + rule() + "\n")
    except KeyboardInterrupt:
        stdout.write("\nOK: quit\n")
        stdout.flush()
        return 0


def _prompt_choice(
    stdin: TextIO,
    stdout: TextIO,
    title: str,
    items: list[str],
    labels: list[str] | None = None,
    *,
    keep: str | None = None,
) -> str | None:
    """One pick from a list. None means the reader backed out.

    `keep` makes an empty line mean "leave this as it is" instead of cancel.
    """
    stdout.write(bold(f"{title}:") + "\n")
    for line in columns(labels if labels is not None else items):
        stdout.write(line + "\n")
    stdout.write(
        status_note("NOTE: pick a number, or a name or its first letters. q cancels.") + "\n"
    )
    stdout.flush()
    line = stdin.readline()
    if line == "":
        return None
    raw = line.strip().lower()
    if raw == "" and keep is not None:
        return keep
    if raw in {"", "q", "quit"}:
        return None
    if raw.isdigit() and 1 <= int(raw) <= len(items):
        return items[int(raw) - 1]
    if raw in items:
        return raw
    hits = [item for item in items if item.startswith(raw)]
    if len(hits) == 1:
        return hits[0]
    stdout.write(status_fail(f"FAIL: not a choice: {raw}") + "\n")
    hint = suggest_choice(raw, items)
    if hint is not None:
        stdout.write(f"Did you mean {hint}?\n")
    stdout.flush()
    return None


def _switch_session(session: dict[str, Any], stdin: TextIO, stdout: TextIO) -> int:
    """Move the session to another problem or language. Work files are per
    problem and language, so nothing on disk is touched."""
    from honepad.cli import toolchain_warning

    opts = problems()
    problem = _prompt_choice(
        stdin, stdout, "problem", opts, [f"{name} ({max_level(name)} levels)" for name in opts]
    )
    if problem is None:
        stdout.write("OK: switch cancelled\n")
        stdout.flush()
        return 0
    current = str(session["lang"])
    langs = [row["id"] for row in languages() if row["id"] in _RUNNERS]
    lang = _prompt_choice(stdin, stdout, f"language (Enter keeps {current})", langs, keep=current)
    if lang is None:
        stdout.write("OK: switch cancelled\n")
        stdout.flush()
        return 0
    note = toolchain_warning(lang)
    if note is not None:
        stdout.write(status_note(note) + "\n")
    nxt = ensure_session(problem, lang)
    session.clear()
    session.update(nxt)
    unlocked = int(session["unlocked"])
    ensure_work_copy(problem, lang, reset=False, level=unlocked)
    refresh_workspace(problem, lang, unlocked, cleared=bool(session.get("cleared")))
    stdout.write(status_unlock(f"OK: {problem} {lang} LEVEL {unlocked}") + "\n")
    stdout.write(work_line(work_src(problem, lang)) + "\n")
    return _print_spec(problem, unlocked, stdout)


def dispatch(
    choice: str, session: dict[str, Any], stdout: TextIO, stdin: TextIO | None = None
) -> int:
    try:
        problem = str(session["problem"])
        lang = str(session["lang"])
        unlocked = int(session["unlocked"])
        if choice in {"1", "run", "test"}:
            return _run_work(problem, lang, unlock=False)
        if choice in {"2", "submit"}:
            if session.get("cleared"):
                stdout.write(status_note("NOTE: replay. Same work-file test.") + "\n")
            else:
                stdout.write(status_note("NOTE: local submit. Nothing is sent.") + "\n")
            stdout.flush()
            return _run_work(problem, lang, unlock=True)
        if choice in {"3", "reset"}:
            return _reset_work(session, stdout)
        if choice in {"4", "spec"}:
            return _print_spec(problem, unlocked, stdout)
        if choice in {"6", "switch"}:
            if stdin is None:
                stdout.write(status_fail("FAIL: switch needs an input stream") + "\n")
                stdout.flush()
                return 1
            return _switch_session(session, stdin, stdout)
        if choice in {"?", "h", "help"}:
            stdout.write(render_help(last_level=bool(session.get("cleared"))) + "\n")
            stdout.flush()
            return 0
        if choice in {"5", "vscode", "code"}:
            work = ensure_work_copy(problem, lang, reset=False, level=unlocked)
            path = write_workspace(problem, lang, unlocked, cleared=bool(session.get("cleared")))
            stdout.write(work_line(work) + "\n")
            stdout.write(f"WORKSPACE: {file_link(path)}\n")
            spec = _spec_output(problem, lang)
            if spec is not None:
                stdout.write(spec + "\n")
            tests = _tests_output(problem, lang)
            if tests is not None:
                stdout.write(tests + "\n")
            stdout.flush()
            return open_vscode(path, [work])
        stdout.write(status_fail(f"FAIL: unknown option {choice!r}") + "\n")
        stdout.write(f"Keys: {render_keys(last_level=bool(session.get('cleared')))}\n")
        stdout.write(status_note("NOTE: ? prints what each key does.") + "\n")
        stdout.flush()
        return 1
    except (KeyError, ValueError, FileNotFoundError, OSError, RuntimeError) as exc:
        stdout.write(status_fail(f"FAIL: {exc}") + "\n")
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
        return spec_line(current)
    public_spec = root / "spec.md"
    if public_spec.is_file():
        return spec_line(public_spec)
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
    print_fail(exc)


def _confirm_unlock(stdin: TextIO, stdout: TextIO, *, live: bool) -> bool | None:
    stdout.write("Submit unlocks the next level if traces pass. Unlock? y / n\n")
    stdout.flush()
    if live:
        with _keys_now(stdin):
            ch = stdin.read(1)
            if ch == "":
                return None
            _drain_pending(stdin)
            stdout.write(f"{ch}\n")
            stdout.flush()
            return ch.lower() == "y"
    line = stdin.readline()
    if line == "":
        return None
    return line.strip().lower() in {"y", "yes"}


def _confirm_reset(session: dict[str, Any], stdin: TextIO, stdout: TextIO) -> str | bool | None:
    unlocked = int(session["unlocked"])
    work = work_src(str(session["problem"]), str(session["lang"]))
    # Every answer here rewrites the work file from the stub, not just `yes`.
    # Say so once, with the path, before offering any of them.
    stdout.write(
        status_fail("3 reset rewrites your work file from the stub. This deletes what you wrote:")
        + "\n"
    )
    stdout.write(f"  {file_link(work)}\n")
    stdout.write(f"Type yes to delete it and stay at level {unlocked}.\n")
    if unlocked > 1:
        stdout.write(f"Type back to delete it and drop to level {unlocked - 1}.\n")
    stdout.write("Type all to delete it and start over at level 1.\n")
    stdout.write(
        status_note(
            "Anything else cancels and keeps the file; q leaves the console. "
            "6 switches problem without deleting."
        )
        + "\n"
    )
    left = remaining_s(int(session["started_at"]), int(session["minutes"]))
    if left == 0:
        stdout.write("NEXT: quit then start starts a new clock and keeps work.\n")
    stdout.flush()
    line = stdin.readline()
    if line == "":
        return None
    confirm = line.strip().lower()
    if confirm in {"y", "yes"}:
        return "work"
    if confirm == "back":
        return "back"
    if confirm == "all":
        return "all"
    if confirm in {"q", "quit"}:
        return "quit"
    stdout.write(status_fail("FAIL: type yes, back, or all") + "\n")
    stdout.flush()
    return False


def _apply_reset(kind: str | bool, session: dict[str, Any], stdout: TextIO) -> int:
    if kind == "back":
        return _reset_back(session, stdout)
    if kind == "all":
        return _reset_all(session, stdout)
    return _reset_work(session, stdout)


def _reset_work(session: dict[str, Any], stdout: TextIO) -> int:
    work = ensure_work_copy(
        str(session["problem"]),
        str(session["lang"]),
        reset=True,
        level=int(session["unlocked"]),
    )
    stdout.write(f"OK: reset\n{work_line(work)}\n")
    stdout.flush()
    return 0


def _reset_back(session: dict[str, Any], stdout: TextIO) -> int:
    unlocked = int(session["unlocked"])
    if unlocked <= 1:
        stdout.write(status_fail("FAIL: already level 1") + "\n")
        stdout.write("NEXT: already LEVEL 1\n")
        stdout.flush()
        return 1
    nxt, work = drop_level(session, minutes=int(session["minutes"]))
    session.clear()
    session.update(nxt)
    stdout.write(f"OK: LEVEL {session['unlocked']}\n{work_line(work)}\n")
    stdout.flush()
    return _print_spec(str(session["problem"]), int(session["unlocked"]), stdout)


def _reset_all(session: dict[str, Any], stdout: TextIO) -> int:
    nxt = restart_all(str(session["problem"]), str(session["lang"]), int(session["minutes"]))
    session.clear()
    session.update(nxt)
    work = ensure_work_copy(str(session["problem"]), str(session["lang"]), reset=True, level=1)
    write_workspace(
        str(session["problem"]),
        str(session["lang"]),
        1,
        cleared=bool(session.get("cleared")),
    )
    stdout.write(f"OK: LEVEL {session['unlocked']}\n{work_line(work)}\n")
    stdout.flush()
    return _print_spec(str(session["problem"]), 1, stdout)


def _load_or_start(args: argparse.Namespace) -> dict[str, Any]:
    from honepad.cli import _swap_start_lang_problem, require_java_path

    _swap_start_lang_problem(args)
    problem = getattr(args, "problem", None)
    lang = getattr(args, "lang", None)
    if (problem is None) != (lang is None):
        raise ValueError("console needs both problem and lang, or neither")
    if problem is None:
        session = load_session()
        if session is None:
            raise ValueError(f"no session. Start with: {invocation()} start bank_system java")
        raw = getattr(args, "minutes", None)
        minutes = int(session["minutes"]) if raw is None else int(raw)
        require_java_path(str(session["lang"]))
        session = ensure_session(str(session["problem"]), str(session["lang"]), minutes=minutes)
    else:
        if problem not in problems():
            raise ValueError(f"invalid problem: {problem}")
        row = language(str(lang))
        if row["id"] not in _RUNNERS:
            raise ValueError(f"no runner for {row['id']}")
        raw = getattr(args, "minutes", None)
        minutes = None if raw is None else int(raw)
        require_java_path(row["id"])
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
        stdout.write(status_fail(f"FAIL: missing spec {spec}") + "\n")
        stdout.flush()
        return 1
    text = paint_spec(spec.read_text(encoding="utf-8"))
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


def _drain_pending(stdin: TextIO) -> None:
    try:
        stdin.fileno()
    except (AttributeError, OSError):
        stdin.read()
        return
    _drain_escape(stdin)


def _read_choice(
    session: dict[str, Any],
    stdin: TextIO,
    stdout: TextIO,
    *,
    live: bool,
    clock_fn: Callable[[], int] | None = None,
    shown_time_up: list[bool] | None = None,
    shown_menu: list[bool] | None = None,
) -> str | None:
    time_up = shown_time_up if shown_time_up is not None else [False]
    menu = shown_menu if shown_menu is not None else [False]

    def _left() -> int:
        if clock_fn is not None:
            return clock_fn()
        return remaining_s(int(session["started_at"]), int(session["minutes"]))

    def _prompt() -> str:
        left = _left()
        return render_prompt(
            format_clock(left),
            seconds=left,
            level=int(session["unlocked"]),
        )

    if not live:
        stdout.write(f"{_prompt()}  > ")
        stdout.flush()
        line = stdin.readline()
        return None if line == "" else line
    with _keys_now(stdin):
        stdout.write(f"\r{_prompt()}\033[K")
        stdout.flush()
        while True:
            ready, _, _ = select.select([stdin], [], [], 1.0)
            if ready:
                ch = stdin.read(1)
                if ch == "":
                    return None
                if ch in {"\n", "\r"}:
                    # Enter on an empty prompt is not a command. Redraw in
                    # place instead of emitting a newline, or holding Enter
                    # walks the prompt down the screen and scrolls the menu
                    # out of view. Show the menu once per burst so the keys
                    # are on screen even when the banner has scrolled off.
                    if not menu[0]:
                        keys = render_keys(last_level=bool(session.get("cleared")))
                        stdout.write(f"\r\033[K{keys}\n")
                        menu[0] = True
                    stdout.write(f"\r{_prompt()}\033[K")
                    stdout.flush()
                    continue
                if ch == "\x1b":
                    _drain_escape(stdin)
                    continue
                if ch.isspace():
                    continue
                stdout.write("\r\033[K\n")
                stdout.flush()
                _drain_pending(stdin)
                return ch
            _reload_session(session)
            left = _left()
            if left > 0:
                time_up[0] = False
            elif not time_up[0]:
                stdout.write("\n" + render_banner(session) + "\n")
                time_up[0] = True
            stdout.write(f"\r{_prompt()}\033[K")
            stdout.flush()
