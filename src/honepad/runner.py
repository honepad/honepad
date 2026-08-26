"""Run traces against a language pack."""

from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import tempfile
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


def run_javascript(problem: str, level: int, kind: str = "solution") -> Report:
    pack = repo_root() / "langs" / "javascript" / "problems" / problem
    src = pack / ("solution.js" if kind == "solution" else "stub.js")
    adapter = repo_root() / "langs" / "javascript" / "adapter.js"
    cases = load_cases(problem, level)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(cases, handle)
        cases_path = handle.name
    proc = subprocess.run(
        ["node", str(adapter), str(src), class_for_problem(problem), cases_path],
        check=False,
        capture_output=True,
        text=True,
    )
    if not proc.stdout.strip():
        raise RuntimeError(proc.stderr or "javascript adapter produced no output")
    payload = json.loads(proc.stdout.splitlines()[-1])
    failed = [
        Fail(
            row["case"],
            row["index"],
            row["method"],
            [],
            row["expected"],
            row["actual"],
        )
        for row in payload.get("failed", [])
    ]
    return Report(problem, "javascript", level, int(payload.get("passed", 0)), failed)


def go_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "go" / "problems" / problem
    name = "solution.go" if kind == "solution" else "stub.go"
    return pack / name


def run_go(problem: str, level: int, kind: str = "solution") -> Report:
    src = go_entry(problem, kind)
    adapter = repo_root() / "langs" / "go" / "adapter.go"
    cases = load_cases(problem, level)
    ctor = class_for_problem(problem)
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        shutil.copy(adapter, tmpdir / "adapter.go")
        shutil.copy(src, tmpdir / src.name)
        (tmpdir / "ctor.go").write_text(
            f"package main\nfunc NewTarget() any {{ return New{ctor}() }}\n",
            encoding="utf-8",
        )
        (tmpdir / "go.mod").write_text("module honepadrun\n\ngo 1.22\n", encoding="utf-8")
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(cases, handle)
            cases_path = handle.name
        proc = subprocess.run(
            ["go", "run", ".", cases_path],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
    if not proc.stdout.strip():
        raise RuntimeError(proc.stderr or "go adapter produced no output")
    payload = json.loads(proc.stdout.splitlines()[-1])
    failed = [
        Fail(
            row["case"],
            row["index"],
            row["method"],
            [],
            row["expected"],
            row["actual"],
        )
        for row in payload.get("failed", [])
    ]
    return Report(problem, "go", level, int(payload.get("passed", 0)), failed)


def rust_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "rust" / "problems" / problem
    name = "solution.rs" if kind == "solution" else "stub.rs"
    return pack / name


def run_rust(problem: str, level: int, kind: str = "solution") -> Report:
    src = rust_entry(problem, kind)
    rust_dir = repo_root() / "langs" / "rust"
    adapter = rust_dir / "adapter.rs"
    harness = rust_dir / "harness.rs"
    cases = load_cases(problem, level)
    ctor = class_for_problem(problem)
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        src_dir = tmpdir / "src"
        src_dir.mkdir()
        shutil.copy(adapter, src_dir / "main.rs")
        shutil.copy(harness, src_dir / "harness.rs")
        shutil.copy(src, src_dir / "solution.rs")
        (src_dir / "ctor.rs").write_text(
            "use crate::harness::Harness;\n"
            f"use crate::solution::{ctor};\n\n"
            "pub fn new_target() -> Box<dyn Harness> {\n"
            f"    Box::new({ctor}::new())\n"
            "}\n",
            encoding="utf-8",
        )
        (tmpdir / "Cargo.toml").write_text(
            "[package]\n"
            'name = "honepadrun"\n'
            'version = "0.1.0"\n'
            'edition = "2021"\n\n'
            "[dependencies]\n"
            'serde = { version = "1", features = ["derive"] }\n'
            'serde_json = "1"\n',
            encoding="utf-8",
        )
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(cases, handle)
            cases_path = handle.name
        proc = subprocess.run(
            ["cargo", "run", "--quiet", "--", cases_path],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
    if not proc.stdout.strip():
        raise RuntimeError(proc.stderr or "rust adapter produced no output")
    payload = json.loads(proc.stdout.splitlines()[-1])
    failed = [
        Fail(
            row["case"],
            row["index"],
            row["method"],
            [],
            row["expected"],
            row["actual"],
        )
        for row in payload.get("failed", [])
    ]
    return Report(problem, "rust", level, int(payload.get("passed", 0)), failed)


def run(
    problem: str,
    lang_id: str,
    level: int,
    kind: str = "solution",
) -> Report:
    row = language(lang_id)
    if row["id"] == "python3":
        return run_python(problem, level, kind)
    if row["id"] == "javascript":
        return run_javascript(problem, level, kind)
    if row["id"] == "go":
        return run_go(problem, level, kind)
    if row["id"] == "rust":
        return run_rust(problem, level, kind)
    raise NotImplementedError(
        f"runner for {lang_id} is a factory job (adapter={row.get('adapter')})"
    )


def map_call(call: dict[str, Any], naming: str) -> dict[str, Any]:
    mapped = dict(call)
    mapped["m"] = method_name(call["m"], naming)
    return mapped
