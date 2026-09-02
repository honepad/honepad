"""Terminal helpers: OSC 8 file links, remaining_s clock, and TTY color."""

from __future__ import annotations

import math
import os
import re
import sys
import time
from pathlib import Path

from honepad.catalog import next_problem

_CODE_SPAN = re.compile(r"`([^`]+)`")

_OSC = "\033]8;;"
_ST = "\033\\"
_RESET = "\033[0m"
_BOLD = "\033[1m"
_DIM = "\033[2m"
_MENU_ITEMS = (
    ("1", "run"),
    ("2", "submit (local)"),
    ("3", "reset / back"),
    ("4", "spec"),
    ("5", "vscode"),
    ("q", "quit"),
)
_LAST_LEVEL_MENU = (
    ("1", "run"),
    ("2", "replay"),
    ("3", "reset / back"),
    ("4", "spec"),
    ("5", "vscode"),
    ("q", "quit"),
)


def color_enabled(*, stream: object | None = None) -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("FORCE_COLOR"):
        return True
    target = sys.stdout if stream is None else stream
    try:
        if not target.isatty():
            return False
    except AttributeError:
        return False
    term = os.environ.get("TERM", "")
    return term not in {"", "dumb"}


def _truecolor() -> bool:
    value = os.environ.get("COLORTERM", "").lower()
    return "truecolor" in value or "24bit" in value


def paint(text: str, *codes: str, enabled: bool | None = None) -> str:
    on = color_enabled() if enabled is None else enabled
    if not on or not codes:
        return text
    return "".join(codes) + text + _RESET


def bold(text: str, *, enabled: bool | None = None) -> str:
    return paint(text, _BOLD, enabled=enabled)


def dim(text: str, *, enabled: bool | None = None) -> str:
    return paint(text, _DIM, enabled=enabled)


def fg256(n: int) -> str:
    return f"\033[38;5;{n}m"


def fg_rgb(r: int, g: int, b: int) -> str:
    return f"\033[38;2;{r};{g};{b}m"


def gradient(text: str, start: tuple[int, int, int], end: tuple[int, int, int]) -> str:
    if not color_enabled():
        return text
    if not text:
        return text
    if not _truecolor() or len(text) == 1:
        return paint(text, _BOLD, fg256(81))
    last = len(text) - 1
    out: list[str] = [_BOLD]
    for i, ch in enumerate(text):
        t = i / last
        r = int(start[0] + (end[0] - start[0]) * t)
        g = int(start[1] + (end[1] - start[1]) * t)
        b = int(start[2] + (end[2] - start[2]) * t)
        out.append(fg_rgb(r, g, b) + ch)
    out.append(_RESET)
    return "".join(out)


def clock_style(seconds: int, clock: str) -> str:
    if seconds <= 0:
        return paint(clock, _BOLD, fg256(196))
    if seconds < 600:
        return paint(clock, _BOLD, fg256(214))
    return paint(clock, _BOLD, fg256(114))


def render_keys(*, last_level: bool = False, enabled: bool | None = None) -> str:
    menu = _LAST_LEVEL_MENU if last_level else _MENU_ITEMS
    items = [
        f"{bold(key, enabled=enabled)} {paint(label, fg256(252), enabled=enabled)}"
        for key, label in menu
    ]
    return "  ".join(items)


def render_prompt(clock: str, *, seconds: int | None = None, level: int | None = None) -> str:
    shown = clock if seconds is None else clock_style(seconds, clock)
    if seconds is None and color_enabled():
        shown = paint(clock, _BOLD, fg256(114))
    prefix = f"[{shown}]"
    if level is not None:
        prefix = f"{prefix} {accent(f'LEVEL {level}')}"
    return prefix


def render_menu(
    clock: str,
    *,
    seconds: int | None = None,
    level: int | None = None,
    last_level: bool = False,
) -> str:
    return (
        f"{render_prompt(clock, seconds=seconds, level=level)} {render_keys(last_level=last_level)}"
    )


def paint_spec(text: str, *, enabled: bool | None = None) -> str:
    on = color_enabled() if enabled is None else enabled
    if not on or not text:
        return text
    out: list[str] = []
    fence = False
    for line in text.splitlines(keepends=True):
        raw = line[:-1] if line.endswith("\n") else line
        nl = "\n" if line.endswith("\n") else ""
        if raw.startswith("```"):
            fence = not fence
            out.append(paint(raw, _DIM, enabled=True) + nl)
            continue
        if fence:
            out.append(paint(raw, fg256(81), enabled=True) + nl)
            continue
        if raw.startswith("#"):
            out.append(paint(raw, _BOLD, fg256(81), enabled=True) + nl)
            continue
        out.append(_paint_inline(raw) + nl)
    return "".join(out)


def _paint_inline(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        return paint(f"`{match.group(1)}`", fg256(114), enabled=True)

    return _CODE_SPAN.sub(repl, text)


def status_ok(text: str) -> str:
    return paint(text, _BOLD, fg256(114))


def status_fail(text: str) -> str:
    return paint(text, _BOLD, fg256(203))


def status_note(text: str) -> str:
    return dim(text)


def status_unlock(text: str) -> str:
    return paint(text, _BOLD, fg256(81))


def accent(text: str) -> str:
    return paint(text, _BOLD, fg256(81))


def invocation(argv0: str | None = None) -> str:
    raw = sys.argv[0] if argv0 is None else argv0
    if not raw:
        return "honepad"
    name = Path(raw).name
    if name in {"__main__.py", "__main__"}:
        exe = Path(sys.executable).name or "python3"
        return f"{exe} -m honepad"
    if name == "honepad" or name.startswith("honepad"):
        return raw
    return "honepad"


def start_next() -> str:
    return f"NEXT: {invocation()} start bank_system java"


_FIREWORK_W = 25
_FIREWORK_H = 11
_FIREWORK_FRAMES = 14
_FIREWORK_DELAY_S = 0.04
_FIREWORK_LAUNCH = 4
_FIREWORK_COLORS = (196, 214, 220, 81, 213, 203)


def firework_frame(step: int, *, color: bool = False) -> list[str]:
    grid = [[" "] * _FIREWORK_W for _ in range(_FIREWORK_H)]
    cx = _FIREWORK_W // 2
    cy = 3
    if step < _FIREWORK_LAUNCH:
        y = max(cy, _FIREWORK_H - 2 - step * 2)
        _plot(grid, cx, y, _spark("*", 220, color))
    else:
        age = step - _FIREWORK_LAUNCH + 1
        mark = "*" if age < 5 else ("+" if age < 8 else ".")
        if age <= 2:
            _plot(grid, cx, cy, _spark("*", 220, color))
        rays = 12
        for i in range(rays):
            ang = i * math.tau / rays
            radius = age * 1.15
            x = cx + int(round(math.cos(ang) * radius * 2.1))
            y = cy + int(round(math.sin(ang) * radius * 0.65))
            _plot(grid, x, y, _spark(mark, _FIREWORK_COLORS[i % len(_FIREWORK_COLORS)], color))
            if age > 2:
                fall = age - 2
                _plot(
                    grid,
                    cx + int(round(math.cos(ang) * radius * 1.2)),
                    y + fall,
                    _spark(".", _FIREWORK_COLORS[(i + 2) % len(_FIREWORK_COLORS)], color),
                )
    return ["".join(row) for row in grid]


def _plot(grid: list[list[str]], x: int, y: int, cell: str) -> None:
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        grid[y][x] = cell


def _spark(ch: str, color: int, on: bool) -> str:
    if not on:
        return ch
    return paint(ch, _BOLD, fg256(color), enabled=True)


def play_firework(*, frames: int = _FIREWORK_FRAMES, delay_s: float = _FIREWORK_DELAY_S) -> None:
    if not color_enabled():
        return
    stream = sys.stdout
    stream.write("\033[?25l")
    height = 0
    try:
        for step in range(frames):
            lines = firework_frame(step, color=True)
            if height:
                stream.write(f"\033[{height}A")
            for line in lines:
                stream.write(line + "\n")
            stream.flush()
            height = len(lines)
            if delay_s > 0:
                time.sleep(delay_s)
    finally:
        stream.write("\033[?25h")
        stream.flush()


def print_complete(
    problem: str, lang: str, *, levels: int, passed: int, first: bool = True
) -> None:
    if first:
        play_firework()
        print(status_unlock(f"DONE: {problem} {lang}"))
    else:
        print(status_ok(f"OK: {problem} {lang} still complete"))
    print(status_note(f"NOTE: all {levels} levels, {passed} traces"))
    nxt = next_problem(problem)
    if nxt is not None:
        print(f"NEXT: {invocation()} start {nxt} {lang}")


def print_fail(exc: BaseException) -> None:
    print(status_fail(f"FAIL: {exc}"))
    text = str(exc)
    if text in {"javac not on PATH", "java not on PATH"}:
        print("NEXT: install a JDK so javac and java are on PATH")
        return
    if text.startswith("no runner for "):
        print(start_next())
        return
    if text.startswith("invalid problem"):
        from honepad.catalog import problems, suggest_choice

        query = text[len("invalid problem") :].lstrip(" :").strip("'\"")
        hint = suggest_choice(query, problems())
        if hint is not None:
            print(f"Did you mean {hint}?")
        print(start_next())
        return
    if not text.startswith("unknown language:"):
        return
    from honepad.catalog import languages, suggest_language
    from honepad.runner import _RUNNERS

    prefer = [row["id"] for row in languages() if row["id"] in _RUNNERS]
    hint = suggest_language(text.split(":", 1)[1].strip(), prefer=prefer)
    if hint is not None:
        print(f"Did you mean {hint}?")
    print(f"NEXT: {invocation()} langs")


def work_reset_next() -> str:
    return f"NEXT: edit the work file or {invocation()} start --reset"


def format_clock(seconds: int) -> str:
    left = seconds if seconds > 0 else 0
    hours, rem = divmod(left, 3600)
    minutes, secs = divmod(rem, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def file_uri(path: Path | str) -> str:
    target = Path(path).expanduser()
    try:
        target = target.resolve()
    except OSError:
        target = target.absolute()
    return target.as_uri()


def file_link(path: Path | str, label: str | None = None) -> str:
    target = Path(path)
    text = label if label is not None else str(target)
    return f"{_OSC}{file_uri(target)}{_ST}{text}{_OSC}{_ST}"


def work_line(path: Path | str) -> str:
    return f"{accent('WORK:')} {file_link(path)}"


def spec_line(path: Path | str) -> str:
    return f"{accent('SPEC:')} {file_link(path)}"
