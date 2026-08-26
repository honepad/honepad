"""Practice session: 90-minute remaining_s and level unlock."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from honepad.traces import problem_dir


def session_path() -> Path:
    override = os.environ.get("HONEPAD_SESSION")
    if override:
        return Path(override)
    return Path.home() / ".honepad" / "session.json"


def max_level(problem: str) -> int:
    specs = list((problem_dir(problem) / "spec").glob("level*.md"))
    if not specs:
        return 1
    return max(int(path.stem.removeprefix("level")) for path in specs)


def remaining_s(started_at: int, minutes: int, now: int | None = None) -> int:
    now_ts = int(time.time()) if now is None else now
    left = started_at + minutes * 60 - now_ts
    return left if left > 0 else 0


def load_session(path: Path | None = None) -> dict[str, Any] | None:
    target = path or session_path()
    if not target.is_file():
        return None
    payload = json.loads(target.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{target} must be a JSON object")
    return payload


def save_session(session: dict[str, Any], path: Path | None = None) -> Path:
    target = path or session_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(session, indent=2) + "\n", encoding="utf-8")
    return target


def new_session(problem: str, lang: str, minutes: int = 90) -> dict[str, Any]:
    return {
        "problem": problem,
        "lang": lang,
        "started_at": int(time.time()),
        "minutes": minutes,
        "unlocked": 1,
    }


def ensure_session(
    problem: str,
    lang: str,
    minutes: int = 90,
    reset: bool = False,
) -> dict[str, Any]:
    current = None if reset else load_session()
    if current is None or current.get("problem") != problem:
        session = new_session(problem, lang, minutes)
        save_session(session)
        return session
    current["lang"] = lang
    save_session(current)
    return current


def unlock_next(session: dict[str, Any]) -> int | None:
    nxt = int(session["unlocked"]) + 1
    if nxt > max_level(str(session["problem"])):
        return None
    session["unlocked"] = nxt
    save_session(session)
    return nxt
