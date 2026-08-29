"""Terminal helpers: OSC 8 file links, remaining_s clock, and TTY color."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

_CODE_SPAN = re.compile(r"`([^`]+)`")

_OSC = "\033]8;;"
_ST = "\033\\"
_RESET = "\033[0m"
_BOLD = "\033[1m"
_DIM = "\033[2m"
_MENU_ITEMS = (
    ("1", "run"),
    ("2", "submit (local)"),
    ("3", "reset work"),
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


def render_keys(*, enabled: bool | None = None) -> str:
    items = [
        f"{bold(key, enabled=enabled)} {paint(label, fg256(252), enabled=enabled)}"
        for key, label in _MENU_ITEMS
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


def render_menu(clock: str, *, seconds: int | None = None, level: int | None = None) -> str:
    return f"{render_prompt(clock, seconds=seconds, level=level)} {render_keys()}"


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
