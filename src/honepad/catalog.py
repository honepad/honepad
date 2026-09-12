"""Load the language catalog."""

from __future__ import annotations

import difflib
import json
import os
from pathlib import Path
from typing import Any


def resolve_repo_root(module_file: Path, env: str | None) -> Path:
    """Checkout first, then a bundled wheel tree, then the checkout guess.

    ``HONEPAD_ROOT`` wins so tests and a relocated data dir can pin the tree.
    An editable checkout keeps ``langs/`` next to ``src/``. A wheel copies
    those trees under ``honepad/_data``.
    """
    if env:
        return Path(env)
    checkout = module_file.parents[2]
    if (checkout / "langs" / "catalog.json").is_file():
        return checkout
    bundled = module_file.parent / "_data"
    if (bundled / "langs" / "catalog.json").is_file():
        return bundled
    return checkout


def repo_root() -> Path:
    return resolve_repo_root(Path(__file__).resolve(), os.environ.get("HONEPAD_ROOT"))


def load_catalog() -> dict[str, Any]:
    path = repo_root() / "langs" / "catalog.json"
    return json.loads(path.read_text(encoding="utf-8"))


def languages() -> list[dict[str, Any]]:
    return list(load_catalog()["languages"])


def language_ids() -> list[str]:
    return [row["id"] for row in languages()]


def language(lang_id: str) -> dict[str, Any]:
    for row in languages():
        if row["id"] == lang_id:
            return row
    raise ValueError(f"unknown language: {lang_id}")


# README names (C#, C++, JS, TS) plus short tokens for the seven
# all-platform desks. Fold case before lookup so C# and c# both bind.
_LANGUAGE_ALIASES = {
    "c#": "csharp",
    "cs": "csharp",
    "c++": "cpp",
    "js": "javascript",
    "node": "javascript",
    "ts": "typescript",
}


def resolve_language_token(token: str) -> str | None:
    ids = language_ids()
    alias = _LANGUAGE_ALIASES.get(token.casefold())
    if alias is not None:
        return alias
    if token in ids:
        return token
    hits = [item for item in ids if item.startswith(token)]
    if len(hits) == 1:
        return hits[0]
    return None


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
