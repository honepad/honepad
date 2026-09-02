"""Load the language catalog."""

from __future__ import annotations

import difflib
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "langs" / "catalog.json"


def repo_root() -> Path:
    return ROOT


def load_catalog() -> dict[str, Any]:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def languages() -> list[dict[str, Any]]:
    return list(load_catalog()["languages"])


def language_ids() -> list[str]:
    return [row["id"] for row in languages()]


def language(lang_id: str) -> dict[str, Any]:
    for row in languages():
        if row["id"] == lang_id:
            return row
    raise ValueError(f"unknown language: {lang_id}")


def suggest_language(lang_id: str, *, prefer: list[str] | None = None) -> str | None:
    pool = prefer if prefer is not None else language_ids()
    match = _close_language(lang_id, pool)
    if match is not None:
        return match
    if prefer is not None:
        return _close_language(lang_id, language_ids())
    return None


def suggest_choice(query: str, items: list[str]) -> str | None:
    return _close_language(query, items)


def _close_language(query: str, ids: list[str]) -> str | None:
    if not query or not ids:
        return None
    prefixes = [item for item in ids if item.startswith(query)]
    if prefixes:
        return min(prefixes, key=len)
    close = difflib.get_close_matches(query, ids, n=1)
    if close:
        return close[0]
    hits = [item for item in ids if _chars_in_order(query, item)]
    if hits:
        return min(hits, key=len)
    return None


def _chars_in_order(query: str, candidate: str) -> bool:
    index = 0
    for char in candidate:
        if char == query[index]:
            index += 1
            if index == len(query):
                return True
    return False


def required_ids() -> list[str]:
    return list(load_catalog()["required_ids"])


def problems() -> list[str]:
    return list(load_catalog()["problems"])


def next_problem(current: str) -> str | None:
    ids = problems()
    try:
        index = ids.index(current)
    except ValueError:
        return None
    if index + 1 >= len(ids):
        return None
    return ids[index + 1]
