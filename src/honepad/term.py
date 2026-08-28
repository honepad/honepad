"""Terminal helpers: OSC 8 file links and remaining_s clock."""

from __future__ import annotations

import sys
from pathlib import Path

_OSC = "\033]8;;"
_ST = "\033\\"


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
    return f"WORK: {file_link(path)}"
