"""Practice session: 90-minute remaining_s and level unlock."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from honepad.catalog import language, problems, repo_root
from honepad.traces import problem_dir
from honepad.workstub import (
    class_name_for,
    merge_unlocked_methods,
    methods_through_level,
    naming_for,
    slice_stub,
)


def session_path() -> Path:
    override = os.environ.get("HONEPAD_SESSION")
    if override:
        return Path(override)
    return Path.home() / ".honepad" / "session.json"


def work_src(problem: str, lang_id: str) -> Path:
    ext = str(language(lang_id)["ext"])
    parent = session_path().parent / "work" / problem / lang_id
    if ext == "java":
        dest = parent / f"{class_name_for(problem)}.java"
        _migrate_legacy_java_work(parent, dest)
        return dest
    return parent / f"work.{ext}"


def _migrate_legacy_java_work(parent: Path, dest: Path) -> None:
    legacy = parent / "work.java"
    if dest.exists() or dest.is_symlink():
        if legacy.is_file() or legacy.is_symlink():
            legacy.unlink()
        return
    if not legacy.is_file():
        return
    try:
        legacy.rename(dest)
    except OSError:
        dest.write_text(legacy.read_text(encoding="utf-8"), encoding="utf-8")
        legacy.unlink()


def ensure_work_copy(problem: str, lang_id: str, *, reset: bool, level: int) -> Path:
    dest = work_src(problem, lang_id)
    dest.parent.mkdir(parents=True, exist_ok=True)
    row = language(lang_id)
    ext = str(row["ext"])
    stub = repo_root() / "langs" / lang_id / "problems" / problem / f"stub.{ext}"
    full = stub.read_text(encoding="utf-8")
    naming = naming_for(lang_id)
    allowed = methods_through_level(problem, level, naming)
    if dest.is_file() and not reset:
        current = dest.read_text(encoding="utf-8")
        class_name = class_name_for(problem)
        if class_name in current:
            merged = merge_unlocked_methods(current, full, ext, allowed)
            if merged != current:
                dest.write_text(merged, encoding="utf-8")
        return dest
    sliced = slice_stub(full, ext, allowed, class_name_for(problem))
    dest.write_text(sliced, encoding="utf-8")
    return dest


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
    try:
        payload = json.loads(target.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"{target}: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError(f"{target} must be a JSON object")
    required = ("problem", "lang", "started_at", "minutes", "unlocked")
    for key in required:
        if key not in payload:
            raise ValueError(f"{target} missing {key}")
    try:
        payload["started_at"] = int(payload["started_at"])
        payload["minutes"] = int(payload["minutes"])
        payload["unlocked"] = int(payload["unlocked"])
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{target} {exc}") from exc
    problem = str(payload["problem"])
    lang = str(payload["lang"])
    if not _single_segment(problem) or problem not in problems():
        raise ValueError(f"invalid problem {problem!r}")
    try:
        language(lang)
    except KeyError as exc:
        raise ValueError(f"unknown language: {lang}") from exc
    payload["problem"] = problem
    payload["lang"] = lang
    return payload


def _single_segment(name: str) -> bool:
    if not name or name in {".", ".."}:
        return False
    if "/" in name or "\\" in name:
        return False
    return Path(name).name == name


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
