"""Load language-neutral JSON traces."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from honepad.catalog import repo_root


def problem_dir(problem: str) -> Path:
    path = repo_root() / "problems" / problem
    if not path.is_dir():
        raise FileNotFoundError(f"unknown problem: {problem}")
    return path


def load_cases(problem: str, level: int | None = None) -> list[dict[str, Any]]:
    cases_dir = problem_dir(problem) / "cases"
    cases: list[dict[str, Any]] = []
    for path in sorted(cases_dir.glob("*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"{path}: {exc}") from exc
        if not isinstance(payload, list):
            raise ValueError(f"{path} must be a JSON list")
        for case in payload:
            if level is None or int(case["level"]) <= level:
                cases.append(case)
    return cases


_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def method_name(snake: str, naming: str) -> str:
    if naming == "snake":
        name = snake
    elif naming == "camel":
        parts = snake.split("_")
        name = parts[0] + "".join(p.title() for p in parts[1:])
    else:
        raise ValueError(f"unknown naming: {naming}")
    if _IDENT.fullmatch(name) is None:
        raise ValueError(f"invalid method name: {name}")
    return name
