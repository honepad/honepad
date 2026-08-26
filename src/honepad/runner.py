"""Run traces against a language pack."""

from __future__ import annotations

import importlib.util
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from honepad.catalog import language, repo_root
from honepad.traces import load_cases, method_name


@dataclass
class Fail:
    case: str
    index: int
    method: str
    args: list[Any]
    expected: Any
    actual: Any


@dataclass
class Report:
    problem: str
    lang: str
    level: int
    passed: int
    failed: list[Fail]

    @property
    def ok(self) -> bool:
        return not self.failed


def _load_python_class(path: Path, class_name: str) -> Any:
    spec = importlib.util.spec_from_file_location("honepad_user_mod", path)
    if spec is None or spec.loader is None:
        raise FileNotFoundError(path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return getattr(mod, class_name)


def python_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "python3" / "problems" / problem
    name = "solution.py" if kind == "solution" else "stub.py"
    return pack / name


def class_for_problem(problem: str) -> str:
    return {
        "bank_system": "Simulation",
        "in_memory_database": "InMemoryDatabase",
        "file_storage": "Simulation",
        "workers": "Simulation",
    }[problem]


def run_python(
    problem: str,
    level: int,
    kind: str = "solution",
) -> Report:
    cls = _load_python_class(python_entry(problem, kind), class_for_problem(problem))
    cases = load_cases(problem, level)
    failed: list[Fail] = []
    passed = 0
    for case in cases:
        obj = cls()
        for i, call in enumerate(case["calls"]):
            method = call["m"]
            args = list(call["a"])
            expected = call["e"]
            fn = getattr(obj, method)
            try:
                actual = fn(*args)
            except Exception as exc:  # noqa: BLE001 - user pack
                failed.append(
                    Fail(case["id"], i, method, args, expected, f"exc:{type(exc).__name__}")
                )
                break
            if actual != expected:
                failed.append(Fail(case["id"], i, method, args, expected, actual))
                break
        else:
            passed += 1
    return Report(problem, "python3", level, passed, failed)


def run(
    problem: str,
    lang_id: str,
    level: int,
    kind: str = "solution",
) -> Report:
    row = language(lang_id)
    if row["id"] == "python3":
        return run_python(problem, level, kind)
    raise NotImplementedError(
        f"runner for {lang_id} is a factory job (adapter={row.get('adapter')})"
    )


def map_call(call: dict[str, Any], naming: str) -> dict[str, Any]:
    mapped = dict(call)
    mapped["m"] = method_name(call["m"], naming)
    return mapped
