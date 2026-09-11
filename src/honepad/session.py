"""Practice session: 90-minute remaining_s and level unlock."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, TextIO

from honepad.catalog import language, problems, repo_root, resolve_language_token
from honepad.traces import problem_dir
from honepad.workstub import (
    class_name_for,
    declares_class,
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


def _require_real_session_dir(path: Path, label: str) -> None:
    bound = session_path().parent.resolve()
    if path.is_symlink():
        raise RuntimeError(f"{label} is a symlink: {path}")
    if not path.is_dir():
        raise RuntimeError(f"{label} is not a directory: {path}")
    resolved = path.resolve()
    if not resolved.is_dir():
        raise RuntimeError(f"{label} is not a directory: {path}")
    if not resolved.is_relative_to(bound):
        raise RuntimeError(f"{label} escapes session: {path}")


def _ensure_real_session_dir(path: Path, label: str) -> None:
    bound = session_path().parent
    cursor = path
    missing: list[Path] = []
    while True:
        try:
            cursor.relative_to(bound)
        except ValueError as exc:
            raise RuntimeError(f"{label} escapes session: {path}") from exc
        if cursor.exists() or cursor.is_symlink():
            _require_real_session_dir(cursor, label)
            break
        if cursor == bound:
            cursor.mkdir(parents=True, exist_ok=True)
            _require_real_session_dir(cursor, label)
            break
        missing.append(cursor)
        parent = cursor.parent
        if parent == cursor:
            raise RuntimeError(f"{label} escapes session: {path}")
        cursor = parent
    for created in reversed(missing):
        created.mkdir(parents=False, exist_ok=True)
        _require_real_session_dir(created, label)


def extra_work_sources(problem: str, lang_id: str) -> list[Path]:
    work = work_src(problem, lang_id)
    ext = str(language(lang_id)["ext"])
    extras: list[Path] = []
    if not work.parent.is_dir():
        return extras
    for path in sorted(work.parent.glob(f"*.{ext}")):
        if path.resolve() != work.resolve():
            extras.append(path)
    return extras


def extra_work_note(problem: str, lang_id: str) -> str | None:
    extras = extra_work_sources(problem, lang_id)
    if not extras:
        return None
    names = ", ".join(path.name for path in extras)
    cls = class_name_for(problem)
    work = work_src(problem, lang_id)
    return f"NOTE: {names} is ignored. Put the {cls} class in {work.name}."


def mark_cleared(session: dict[str, Any]) -> dict[str, Any]:
    session["cleared"] = True
    save_session(session)
    return session


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


def _replace_text(dest: Path, text: str) -> None:
    fd, tmp_name = tempfile.mkstemp(prefix=".work.", suffix=".tmp", dir=str(dest.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(tmp_name, dest)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass  # leftover tmp from a failed atomic replace
        raise


def ensure_work_copy(
    problem: str, lang_id: str, *, reset: bool, level: int, require_merge: bool = False
) -> Path:
    _ensure_real_session_dir(session_path().parent / "work" / problem / lang_id, "work")
    dest = work_src(problem, lang_id)
    if dest.is_symlink():
        raise RuntimeError(f"work file is a symlink: {dest}")
    row = language(lang_id)
    ext = str(row["ext"])
    stub = repo_root() / "langs" / lang_id / "problems" / problem / f"stub.{ext}"
    full = stub.read_text(encoding="utf-8")
    naming = naming_for(lang_id)
    allowed = methods_through_level(problem, level, naming)
    if dest.is_file() and not reset:
        current = dest.read_text(encoding="utf-8")
        class_name = class_name_for(problem)
        if declares_class(current, ext, class_name):
            merged = merge_unlocked_methods(current, full, ext, allowed, class_name)
            if merged != current:
                _replace_text(dest, merged)
        elif require_merge:
            raise ValueError(
                f"work file exists but has no {class_name} class, "
                f"edit WORK or honepad start --reset: {dest}"
            )
        write_work_spec(problem, level, dest.parent)
        return dest
    sliced = slice_stub(full, ext, allowed, class_name_for(problem))
    _replace_text(dest, sliced)
    write_work_spec(problem, level, dest.parent)
    return dest


def write_work_spec(problem: str, level: int, dest_dir: Path) -> Path | None:
    src = problem_dir(problem) / "spec" / f"level{level}.md"
    if not src.is_file():
        return None
    dest = dest_dir / "spec.md"
    _replace_text(dest, src.read_text(encoding="utf-8"))
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


class RetiredLanguage(Exception):
    """Stored session lang is gone from the catalog; start a new desk."""

    def __init__(self, lang: str, unlocked: int, problem: str) -> None:
        self.lang = lang
        self.unlocked = unlocked
        self.problem = problem
        super().__init__(lang)


def load_session(
    path: Path | None = None, *, replace_lang: str | None = None
) -> dict[str, Any] | None:
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
        started_at = int(payload["started_at"])
        minutes = int(payload["minutes"])
        unlocked = int(payload["unlocked"])
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError(f"{target} {exc}") from exc
    if minutes < 1:
        raise ValueError(f"{target} minutes must be >= 1")
    problem = str(payload["problem"])
    lang = str(payload["lang"])
    if not _single_segment(problem) or problem not in problems():
        raise ValueError(f"{target}: invalid problem {problem!r}")
    try:
        language(lang)
    except (KeyError, ValueError) as exc:
        resolved = resolve_language_token(lang)
        if resolved is not None:
            lang = resolved
        elif replace_lang is not None:
            resolved = resolve_language_token(replace_lang)
            if resolved is None:
                raise ValueError(f"unknown language: {replace_lang}") from exc
            raise RetiredLanguage(lang, unlocked, problem) from exc
        else:
            raise ValueError(f"{target}: unknown language: {lang}") from exc
    top = max_level(problem)
    if unlocked < 1 or unlocked > top:
        raise ValueError(f"{target} unlocked must be 1..{top}")
    loaded: dict[str, Any] = {
        "problem": problem,
        "lang": lang,
        "started_at": started_at,
        "minutes": minutes,
        "unlocked": unlocked,
        "cleared": bool(payload.get("cleared")),
    }
    last_run = _parse_last_run(payload.get("last_run"))
    if last_run is not None:
        loaded["last_run"] = last_run
    return loaded


def _parse_last_run(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    try:
        parsed: dict[str, Any] = {
            "level": int(raw["level"]),
            "passed": int(raw["passed"]),
            "failed": int(raw["failed"]),
        }
    except (KeyError, TypeError, ValueError, OverflowError):
        return None
    if raw.get("hidden") is True:
        parsed["hidden"] = True
    return parsed


def record_last_run(
    session: dict[str, Any],
    *,
    level: int,
    passed: int,
    failed: int,
    hidden: bool = False,
) -> None:
    last_run: dict[str, Any] = {
        "level": int(level),
        "passed": int(passed),
        "failed": int(failed),
    }
    if hidden:
        last_run["hidden"] = True
    session["last_run"] = last_run
    save_session(session)


def format_debrief(session: dict[str, Any], now: int | None = None) -> str:
    problem = str(session["problem"])
    lang = str(session["lang"])
    unlocked = int(session["unlocked"])
    top = max_level(problem)
    minutes = int(session["minutes"])
    left = remaining_s(int(session["started_at"]), minutes, now=now)
    used = minutes * 60 - left
    lines = [
        f"DEBRIEF: {problem} {lang} LEVEL {unlocked}/{top}",
        f"used {used // 60}m left {left // 60}m",
    ]
    last = session.get("last_run")
    if isinstance(last, dict) and {"level", "passed", "failed"} <= last.keys():
        kind = "last hidden through" if last.get("hidden") else "last through"
        lines.append(
            f"{kind} LEVEL {last['level']} passed={last['passed']} failed={last['failed']}"
        )
    else:
        lines.append("last run: none")
    return "\n".join(lines)


def _single_segment(name: str) -> bool:
    if not name or name in {".", ".."}:
        return False
    if "/" in name or "\\" in name:
        return False
    return Path(name).name == name


def save_session(session: dict[str, Any], path: Path | None = None) -> Path:
    target = path or session_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "problem": session["problem"],
        "lang": session["lang"],
        "started_at": int(session["started_at"]),
        "minutes": int(session["minutes"]),
        "unlocked": int(session["unlocked"]),
    }
    if session.get("cleared"):
        payload["cleared"] = True
    last_run = _parse_last_run(session.get("last_run"))
    if last_run is not None:
        payload["last_run"] = last_run
    fd, tmp_name = tempfile.mkstemp(prefix=".session.", suffix=".tmp", dir=str(target.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, indent=2) + "\n")
        os.replace(tmp_name, target)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass  # leftover tmp from a failed atomic replace
        raise
    return target


def require_minutes(minutes: int) -> int:
    value = int(minutes)
    if value < 1:
        raise ValueError("minutes must be >= 1")
    return value


def new_session(problem: str, lang: str, minutes: int = 90) -> dict[str, Any]:
    return {
        "problem": problem,
        "lang": lang,
        "started_at": int(time.time()),
        "minutes": require_minutes(minutes),
        "unlocked": 1,
    }


def ensure_session(
    problem: str,
    lang: str,
    minutes: int | None = None,
    reset: bool = False,
) -> dict[str, Any]:
    retired: RetiredLanguage | None = None
    try:
        current = None if reset else load_session(replace_lang=lang)
    except RetiredLanguage as exc:
        retired = exc
        current = None
    duration = 90 if minutes is None else minutes
    if current is None or current.get("problem") != problem:
        session = new_session(problem, lang, duration)
        save_session(session)
        if retired is not None:
            if _single_segment(retired.lang):
                try:
                    leftover = work_src(retired.problem, retired.lang)
                except (KeyError, ValueError):
                    leftover = session_path().parent / "work" / retired.problem / retired.lang
            else:
                leftover = retired.lang
            sys.stdout.write(
                f"NOTE: your {retired.lang} session is retired "
                f"({retired.lang} was removed, was LEVEL {retired.unlocked}); "
                f"leftover work stays in {leftover}; "
                f"starting {lang} at LEVEL 1.\n"
            )
        return session
    current.pop("clock_restarted", None)
    current.pop("clock_now_minutes", None)
    if current["lang"] != lang:
        current["cleared"] = False
        current.pop("last_run", None)
    current["lang"] = lang
    left = remaining_s(int(current["started_at"]), int(current["minutes"]))
    restarted = False
    now_minutes: int | None = None
    if left == 0:
        current["started_at"] = int(time.time())
        current["minutes"] = require_minutes(duration)
        restarted = True
    elif minutes is not None and int(current["minutes"]) != minutes:
        current["minutes"] = require_minutes(minutes)
        now_minutes = int(current["minutes"])
        if remaining_s(int(current["started_at"]), now_minutes) == 0:
            current["started_at"] = int(time.time())
    save_session(current)
    current["clock_restarted"] = restarted
    if now_minutes is not None:
        current["clock_now_minutes"] = now_minutes
    return current


def note_clock_restarted(
    session: dict[str, Any],
    *,
    work_kept: bool = True,
    stdout: TextIO | None = None,
) -> None:
    out = sys.stdout if stdout is None else stdout
    if session.pop("clock_restarted", False):
        if work_kept:
            out.write("NOTE: previous clock was 0. New clock started. Work file kept.\n")
        else:
            out.write("NOTE: previous clock was 0. New clock started.\n")
    now_minutes = session.pop("clock_now_minutes", None)
    if now_minutes is not None:
        out.write(f"NOTE: clock is now {now_minutes} minutes\n")


def unlock_next(session: dict[str, Any]) -> int | None:
    nxt = int(session["unlocked"]) + 1
    if nxt > max_level(str(session["problem"])):
        return None
    session["unlocked"] = nxt
    session["cleared"] = False
    save_session(session)
    return nxt


def lock_to_level(session: dict[str, Any], level: int) -> dict[str, Any]:
    if level < 1:
        raise ValueError("already level 1")
    top = max_level(str(session["problem"]))
    if level > top:
        raise ValueError(f"level {level} > max {top}")
    session["unlocked"] = level
    session["cleared"] = False
    save_session(session)
    return session


def restart_all(problem: str, lang: str, minutes: int = 90) -> dict[str, Any]:
    session = new_session(problem, lang, minutes)
    save_session(session)
    return session


def slice_work_to_level(problem: str, lang_id: str, level: int) -> Path:
    return ensure_work_copy(problem, lang_id, reset=True, level=level)


def drop_level(session: dict[str, Any], minutes: int | None = None) -> tuple[dict[str, Any], Path]:
    from honepad.workspace import refresh_workspace

    unlocked = int(session["unlocked"])
    if unlocked <= 1:
        raise ValueError("already level 1")
    problem = str(session["problem"])
    lang_id = str(session["lang"])
    target = unlocked - 1
    work = slice_work_to_level(problem, lang_id, target)
    session = lock_to_level(session, target)
    if minutes is not None and int(session["minutes"]) != minutes:
        session["minutes"] = require_minutes(minutes)
        save_session(session)
    refresh_workspace(
        problem,
        lang_id,
        int(session["unlocked"]),
        cleared=bool(session.get("cleared")),
    )
    loaded = load_session()
    if loaded is None:
        raise ValueError("session missing after drop_level")
    return loaded, work
