"""Run traces against a language pack."""

from __future__ import annotations

import importlib.util
import json
import os
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


def report_from_proc(
    proc: subprocess.CompletedProcess[str],
    problem: str,
    lang_id: str,
    level: int,
) -> Report:
    if not proc.stdout.strip():
        raise RuntimeError(proc.stderr or f"{lang_id} adapter produced no output")
    payload = json.loads(proc.stdout.splitlines()[-1])
    failed = [
        Fail(row["case"], row["index"], row["method"], [], row["expected"], row["actual"])
        for row in payload.get("failed", [])
    ]
    return Report(problem, lang_id, level, int(payload.get("passed", 0)), failed)


def run_compiled(
    problem: str,
    lang_id: str,
    level: int,
    prepare,
) -> Report:
    """prepare(tmpdir: Path, cases_path: str) -> list[str]  (argv to run in tmpdir)."""
    cases = load_cases(problem, level)
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(cases, handle)
            cases_path = handle.name
        argv = prepare(tmpdir, cases_path)
        proc = subprocess.run(argv, check=False, capture_output=True, text=True, cwd=tmpdir)
    return report_from_proc(proc, problem, lang_id, level)


def run_script(
    problem: str,
    lang_id: str,
    level: int,
    kind: str,
    argv: list[str],
) -> Report:
    cases = load_cases(problem, level)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(cases, handle)
        cases_path = handle.name
    proc = subprocess.run(
        [*argv, cases_path],
        check=False,
        capture_output=True,
        text=True,
    )
    return report_from_proc(proc, problem, lang_id, level)


def run_javascript(problem: str, level: int, kind: str = "solution") -> Report:
    pack = repo_root() / "langs" / "javascript" / "problems" / problem
    src = pack / ("solution.js" if kind == "solution" else "stub.js")
    adapter = repo_root() / "langs" / "javascript" / "adapter.js"
    return run_script(
        problem,
        "javascript",
        level,
        kind,
        ["node", str(adapter), str(src), class_for_problem(problem)],
    )


def run_ruby(problem: str, level: int, kind: str = "solution") -> Report:
    pack = repo_root() / "langs" / "ruby" / "problems" / problem
    src = pack / ("solution.rb" if kind == "solution" else "stub.rb")
    adapter = repo_root() / "langs" / "ruby" / "adapter.rb"
    return run_script(
        problem,
        "ruby",
        level,
        kind,
        ["ruby", str(adapter), str(src), class_for_problem(problem)],
    )


def run_php(problem: str, level: int, kind: str = "solution") -> Report:
    pack = repo_root() / "langs" / "php" / "problems" / problem
    src = pack / ("solution.php" if kind == "solution" else "stub.php")
    adapter = repo_root() / "langs" / "php" / "adapter.php"
    return run_script(
        problem,
        "php",
        level,
        kind,
        ["php", str(adapter), str(src), class_for_problem(problem)],
    )


def go_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "go" / "problems" / problem
    name = "solution.go" if kind == "solution" else "stub.go"
    return pack / name


def run_go(problem: str, level: int, kind: str = "solution") -> Report:
    src = go_entry(problem, kind)
    adapter = repo_root() / "langs" / "go" / "adapter.go"
    ctor = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(adapter, tmpdir / "adapter.go")
        shutil.copy(src, tmpdir / src.name)
        (tmpdir / "ctor.go").write_text(
            f"package main\nfunc NewTarget() any {{ return New{ctor}() }}\n",
            encoding="utf-8",
        )
        (tmpdir / "go.mod").write_text("module honepadrun\n\ngo 1.22\n", encoding="utf-8")
        return ["go", "run", ".", cases_path]

    return run_compiled(problem, "go", level, prepare)


def rust_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "rust" / "problems" / problem
    name = "solution.rs" if kind == "solution" else "stub.rs"
    return pack / name


def run_rust(problem: str, level: int, kind: str = "solution") -> Report:
    src = rust_entry(problem, kind)
    rust_dir = repo_root() / "langs" / "rust"
    adapter = rust_dir / "adapter.rs"
    harness = rust_dir / "harness.rs"
    ctor = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
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
        return ["cargo", "run", "--quiet", "--", cases_path]

    return run_compiled(problem, "rust", level, prepare)


def java_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "java" / "problems" / problem
    name = "solution.java" if kind == "solution" else "stub.java"
    return pack / name


def run_java(problem: str, level: int, kind: str = "solution") -> Report:
    src = java_entry(problem, kind)
    java_dir = repo_root() / "langs" / "java"
    class_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(java_dir / "Adapter.java", tmpdir / "Adapter.java")
        shutil.copy(java_dir / "MiniJson.java", tmpdir / "MiniJson.java")
        shutil.copy(src, tmpdir / f"{class_name}.java")
        compiled = subprocess.run(
            ["javac", "Adapter.java", "MiniJson.java", f"{class_name}.java"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "javac failed")
        return ["java", "Adapter", cases_path, class_name]

    return run_compiled(problem, "java", level, prepare)


def csharp_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "csharp" / "problems" / problem
    name = "solution.cs" if kind == "solution" else "stub.cs"
    return pack / name


def run_csharp(problem: str, level: int, kind: str = "solution") -> Report:
    src = csharp_entry(problem, kind)
    csharp_dir = repo_root() / "langs" / "csharp"
    class_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(csharp_dir / "Adapter.cs", tmpdir / "Adapter.cs")
        shutil.copy(csharp_dir / "honepadrun.csproj", tmpdir / "honepadrun.csproj")
        shutil.copy(src, tmpdir / "Solution.cs")
        os.environ["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
        os.environ["DOTNET_NOLOGO"] = "1"
        os.environ["DOTNET_SKIP_FIRST_TIME_EXPERIENCE"] = "1"
        return ["dotnet", "run", "--quiet", "--", cases_path, class_name]

    return run_compiled(problem, "csharp", level, prepare)


def run_typescript(problem: str, level: int, kind: str = "solution") -> Report:
    pack = repo_root() / "langs" / "typescript" / "problems" / problem
    src = pack / ("solution.ts" if kind == "solution" else "stub.ts")
    adapter = repo_root() / "langs" / "javascript" / "adapter.js"
    return run_script(
        problem,
        "typescript",
        level,
        kind,
        ["node", str(adapter), str(src), class_for_problem(problem)],
    )


def kotlin_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "kotlin" / "problems" / problem
    name = "solution.kt" if kind == "solution" else "stub.kt"
    return pack / name


def _kotlinc() -> str:
    for name in ("kotlinc", "kotlinc-jvm"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("kotlinc not found")


def run_kotlin(problem: str, level: int, kind: str = "solution") -> Report:
    src = kotlin_entry(problem, kind)
    kotlin_dir = repo_root() / "langs" / "kotlin"
    class_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(kotlin_dir / "Adapter.kt", tmpdir / "Adapter.kt")
        shutil.copy(repo_root() / "langs" / "java" / "MiniJson.java", tmpdir / "MiniJson.java")
        shutil.copy(src, tmpdir / "solution.kt")
        # kotlinc type-checks .java sources but does not emit those classes.
        java_compiled = subprocess.run(
            ["javac", "MiniJson.java"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if java_compiled.returncode != 0:
            raise RuntimeError(java_compiled.stderr or java_compiled.stdout or "javac failed")
        compiled = subprocess.run(
            [
                _kotlinc(),
                "Adapter.kt",
                "solution.kt",
                "-classpath",
                ".",
                "-include-runtime",
                "-d",
                "run.jar",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "kotlinc failed")
        return [
            "java",
            "-cp",
            os.pathsep.join(["run.jar", "."]),
            "Adapter",
            cases_path,
            class_name,
        ]

    return run_compiled(problem, "kotlin", level, prepare)


def cpp_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "cpp" / "problems" / problem
    name = "solution.cpp" if kind == "solution" else "stub.cpp"
    return pack / name


def _cxx() -> str:
    for name in ("c++", "g++", "clang++"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("c++ compiler not found")


def run_cpp(problem: str, level: int, kind: str = "solution") -> Report:
    src = cpp_entry(problem, kind)
    cpp_dir = repo_root() / "langs" / "cpp"
    ctor_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(cpp_dir / "adapter.cpp", tmpdir / "adapter.cpp")
        shutil.copy(cpp_dir / "minijson.hpp", tmpdir / "minijson.hpp")
        shutil.copy(cpp_dir / "harness.hpp", tmpdir / "harness.hpp")
        shutil.copy(src, tmpdir / "solution.cpp")
        (tmpdir / "ctor.cpp").write_text(
            '#include "harness.hpp"\n'
            '#include "solution.cpp"\n\n'
            f"Harness* new_target() {{ return new {ctor_name}(); }}\n",
            encoding="utf-8",
        )
        compiled = subprocess.run(
            [_cxx(), "-std=c++17", "-O0", "adapter.cpp", "ctor.cpp", "solution.cpp", "-o", "run"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "c++ compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "cpp", level, prepare)


def swift_entry(problem: str, kind: str) -> Path:
    pack = repo_root() / "langs" / "swift" / "problems" / problem
    name = "solution.swift" if kind == "solution" else "stub.swift"
    return pack / name


def _swiftc() -> str:
    path = shutil.which("swiftc")
    if path:
        return path
    raise RuntimeError("swiftc not found")


def run_swift(problem: str, level: int, kind: str = "solution") -> Report:
    src = swift_entry(problem, kind)
    swift_dir = repo_root() / "langs" / "swift"
    ctor_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(swift_dir / "Adapter.swift", tmpdir / "Adapter.swift")
        shutil.copy(swift_dir / "Harness.swift", tmpdir / "Harness.swift")
        shutil.copy(src, tmpdir / "solution.swift")
        (tmpdir / "ctor.swift").write_text(
            f"func newTarget() -> Harness {{ return {ctor_name}() }}\n",
            encoding="utf-8",
        )
        compiled = subprocess.run(
            [
                _swiftc(),
                "Adapter.swift",
                "Harness.swift",
                "ctor.swift",
                "solution.swift",
                "-o",
                "run",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "swiftc failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "swift", level, prepare)


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
    if row["id"] == "ruby":
        return run_ruby(problem, level, kind)
    if row["id"] == "php":
        return run_php(problem, level, kind)
    if row["id"] == "go":
        return run_go(problem, level, kind)
    if row["id"] == "rust":
        return run_rust(problem, level, kind)
    if row["id"] == "java":
        return run_java(problem, level, kind)
    if row["id"] == "typescript":
        return run_typescript(problem, level, kind)
    if row["id"] == "csharp":
        return run_csharp(problem, level, kind)
    if row["id"] == "kotlin":
        return run_kotlin(problem, level, kind)
    if row["id"] == "cpp":
        return run_cpp(problem, level, kind)
    if row["id"] == "swift":
        return run_swift(problem, level, kind)
    raise NotImplementedError(
        f"runner for {lang_id} is a factory job (adapter={row.get('adapter')})"
    )


def map_call(call: dict[str, Any], naming: str) -> dict[str, Any]:
    mapped = dict(call)
    mapped["m"] = method_name(call["m"], naming)
    return mapped
