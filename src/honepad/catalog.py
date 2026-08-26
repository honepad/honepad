"""Load the language catalog."""

from __future__ import annotations

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


def language(lang_id: str) -> dict[str, Any]:
    for row in languages():
        if row["id"] == lang_id:
            return row
    raise KeyError(f"unknown language: {lang_id}")


def required_ids() -> list[str]:
    return list(load_catalog()["required_ids"])


def problems() -> list[str]:
    return list(load_catalog()["problems"])
