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

RUN_TIMEOUT_S = 30


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
    try:
        spec.loader.exec_module(mod)
        return getattr(mod, class_name)
    except FileNotFoundError:
        raise
    except Exception as exc:  # noqa: BLE001 - user pack load
        raise RuntimeError(f"{path}: {type(exc).__name__}") from exc


def pack_src(lang_id: str, problem: str, kind: str, solution_name: str, stub_name: str) -> Path:
    if kind == "work":
        from honepad.session import work_src

        path = work_src(problem, lang_id)
        if not path.is_file():
            raise FileNotFoundError(f"work file missing: {path}")
        return path
    pack = repo_root() / "langs" / lang_id / "problems" / problem
    return pack / (solution_name if kind == "solution" else stub_name)


def python_entry(problem: str, kind: str) -> Path:
    return pack_src("python3", problem, kind, "solution.py", "stub.py")


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
        cases_path = tmpdir / "cases.json"
        cases_path.write_text(json.dumps(cases), encoding="utf-8")
        argv = prepare(tmpdir, str(cases_path))
        try:
            proc = subprocess.run(
                argv,
                check=False,
                capture_output=True,
                text=True,
                cwd=tmpdir,
                timeout=RUN_TIMEOUT_S,
            )
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(f"{lang_id} timed out after {RUN_TIMEOUT_S}s") from exc
    return report_from_proc(proc, problem, lang_id, level)


def run_script(
    problem: str,
    lang_id: str,
    level: int,
    kind: str,
    argv: list[str],
) -> Report:
    cases = load_cases(problem, level)
    with tempfile.TemporaryDirectory() as tmp:
        cases_path = Path(tmp) / "cases.json"
        cases_path.write_text(json.dumps(cases), encoding="utf-8")
        try:
            proc = subprocess.run(
                [*argv, str(cases_path)],
                check=False,
                capture_output=True,
                text=True,
                timeout=RUN_TIMEOUT_S,
            )
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(f"{lang_id} timed out after {RUN_TIMEOUT_S}s") from exc
    return report_from_proc(proc, problem, lang_id, level)


def run_javascript(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("javascript", problem, kind, "solution.js", "stub.js")
    adapter = repo_root() / "langs" / "javascript" / "adapter.js"
    return run_script(
        problem,
        "javascript",
        level,
        kind,
        ["node", str(adapter), str(src), class_for_problem(problem)],
    )


def run_ruby(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("ruby", problem, kind, "solution.rb", "stub.rb")
    adapter = repo_root() / "langs" / "ruby" / "adapter.rb"
    return run_script(
        problem,
        "ruby",
        level,
        kind,
        ["ruby", str(adapter), str(src), class_for_problem(problem)],
    )


def run_perl(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("perl", problem, kind, "solution.pl", "stub.pl")
    adapter = repo_root() / "langs" / "perl" / "adapter.pl"
    return run_script(
        problem,
        "perl",
        level,
        kind,
        ["perl", str(adapter), str(src), class_for_problem(problem)],
    )


def _lua() -> str:
    for name in ("lua", "lua5.5", "lua5.4", "lua5.3"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("lua not found")


def _tclsh() -> str:
    for name in ("tclsh", "tclsh8.6", "tclsh8.7"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("tclsh not found")


def run_tcl(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("tcl", problem, kind, "solution.tcl", "stub.tcl")
    adapter = repo_root() / "langs" / "tcl" / "adapter.tcl"
    return run_script(
        problem,
        "tcl",
        level,
        kind,
        [_tclsh(), str(adapter), str(src), class_for_problem(problem)],
    )


def _rscript() -> str:
    path = shutil.which("Rscript")
    if path:
        return path
    raise RuntimeError("Rscript not found")


def run_r(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("r", problem, kind, "solution.R", "stub.R")
    adapter = repo_root() / "langs" / "r" / "adapter.R"
    return run_script(
        problem,
        "r",
        level,
        kind,
        [_rscript(), str(adapter), str(src), class_for_problem(problem)],
    )


def _octave() -> str:
    for name in ("octave", "octave-cli"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("octave not found")


def _groovy() -> str:
    path = shutil.which("groovy")
    if path:
        return path
    raise RuntimeError("groovy not found")


def _dart() -> str:
    path = shutil.which("dart")
    if path:
        return path
    raise RuntimeError("dart not found")


def _elixir() -> str:
    path = shutil.which("elixir")
    if path:
        return path
    raise RuntimeError("elixir not found")


def _escript() -> str:
    path = shutil.which("escript")
    if path:
        return path
    raise RuntimeError("escript not found")


def run_elixir(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("elixir", problem, kind, "solution.ex", "stub.ex")
    adapter = repo_root() / "langs" / "elixir" / "adapter.exs"
    return run_script(
        problem,
        "elixir",
        level,
        kind,
        [_elixir(), str(adapter), str(src), class_for_problem(problem)],
    )


def haskell_entry(problem: str, kind: str) -> Path:
    return pack_src("haskell", problem, kind, "solution.hs", "stub.hs")


def _ghc() -> str:
    path = shutil.which("ghc")
    if path:
        return path
    raise RuntimeError("ghc not found")


def run_haskell(problem: str, level: int, kind: str = "solution") -> Report:
    src = haskell_entry(problem, kind)
    haskell_dir = repo_root() / "langs" / "haskell"

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(haskell_dir / "Adapter.hs", tmpdir / "Adapter.hs")
        shutil.copy(haskell_dir / "Harness.hs", tmpdir / "Harness.hs")
        shutil.copy(haskell_dir / "MiniJson.hs", tmpdir / "MiniJson.hs")
        shutil.copy(src, tmpdir / "Solution.hs")
        compiled = subprocess.run(
            [_ghc(), "-O0", "-w", "-o", "run", "Adapter.hs"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "ghc compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "haskell", level, prepare)


def ocaml_entry(problem: str, kind: str) -> Path:
    return pack_src("ocaml", problem, kind, "solution.ml", "stub.ml")


def _ocaml() -> str:
    for name in ("ocamlopt", "ocamlc"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("ocamlopt not found")


def scala_entry(problem: str, kind: str) -> Path:
    return pack_src("scala", problem, kind, "solution.scala", "stub.scala")


def _scalac() -> str:
    path = shutil.which("scalac")
    if path:
        return path
    raise RuntimeError("scalac not found")


def _scala() -> str:
    path = shutil.which("scala")
    if path:
        return path
    raise RuntimeError("scala not found")


def run_scala(problem: str, level: int, kind: str = "solution") -> Report:
    src = scala_entry(problem, kind)
    scala_dir = repo_root() / "langs" / "scala"
    class_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(scala_dir / "Adapter.scala", tmpdir / "Adapter.scala")
        shutil.copy(repo_root() / "langs" / "java" / "MiniJson.java", tmpdir / "MiniJson.java")
        shutil.copy(src, tmpdir / "solution.scala")
        # scalac type-checks .java sources but does not emit those classes.
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
            [_scalac(), "-classpath", ".", "Adapter.scala", "solution.scala"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "scalac failed")
        return [_scala(), "-nc", "-classpath", ".", "Adapter", cases_path, class_name]

    return run_compiled(problem, "scala", level, prepare)


def d_entry(problem: str, kind: str) -> Path:
    return pack_src("d", problem, kind, "solution.d", "stub.d")


def _d_compiler() -> str:
    for name in ("gdc", "ldc2", "dmd"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("d compiler not found")


def _d_compile_cmd(compiler: str) -> list[str]:
    name = Path(compiler).name.lower()
    if name == "gdc" or name.startswith("gdc-"):
        return [compiler, "-O0", "-o", "run", "adapter.d", "solution.d"]
    return [compiler, "-O0", "-of=run", "adapter.d", "solution.d"]


def run_d(problem: str, level: int, kind: str = "solution") -> Report:
    src = d_entry(problem, kind)
    d_dir = repo_root() / "langs" / "d"

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(d_dir / "adapter.d", tmpdir / "adapter.d")
        shutil.copy(src, tmpdir / "solution.d")
        compiled = subprocess.run(
            _d_compile_cmd(_d_compiler()),
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "d compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "d", level, prepare)


def run_ocaml(problem: str, level: int, kind: str = "solution") -> Report:
    src = ocaml_entry(problem, kind)
    ocaml_dir = repo_root() / "langs" / "ocaml"

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(ocaml_dir / "adapter.ml", tmpdir / "adapter.ml")
        shutil.copy(ocaml_dir / "minijson.ml", tmpdir / "minijson.ml")
        shutil.copy(src, tmpdir / "solution.ml")
        compiled = subprocess.run(
            [_ocaml(), "-o", "run", "minijson.ml", "solution.ml", "adapter.ml"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "ocaml compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "ocaml", level, prepare)


def run_erlang(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("erlang", problem, kind, "solution.erl", "stub.erl")
    adapter = repo_root() / "langs" / "erlang" / "adapter.erl"
    return run_script(
        problem,
        "erlang",
        level,
        kind,
        [_escript(), str(adapter), str(src), class_for_problem(problem)],
    )


def run_dart(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("dart", problem, kind, "solution.dart", "stub.dart")
    adapter = repo_root() / "langs" / "dart" / "adapter.dart"
    return run_script(
        problem,
        "dart",
        level,
        kind,
        [_dart(), "run", str(adapter), str(src), class_for_problem(problem)],
    )


def _julia() -> str:
    path = shutil.which("julia")
    if path:
        return path
    raise RuntimeError("julia not found")


def run_julia(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("julia", problem, kind, "solution.jl", "stub.jl")
    adapter = repo_root() / "langs" / "julia" / "adapter.jl"
    return run_script(
        problem,
        "julia",
        level,
        kind,
        [_julia(), str(adapter), str(src), class_for_problem(problem)],
    )


def _coffee() -> list[str]:
    path = shutil.which("coffee")
    if path:
        return [path]
    npx = shutil.which("npx")
    if npx:
        return [npx, "--yes", "-p", "coffeescript@2.7.0", "coffee"]
    raise RuntimeError("coffee not found")


def run_coffeescript(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("coffeescript", problem, kind, "solution.coffee", "stub.coffee")
    adapter = repo_root() / "langs" / "coffeescript" / "adapter.coffee"
    return run_script(
        problem,
        "coffeescript",
        level,
        kind,
        [*_coffee(), str(adapter), str(src), class_for_problem(problem)],
    )


def run_bash(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("bash", problem, kind, "solution.sh", "stub.sh")
    adapter = repo_root() / "langs" / "bash" / "adapter.sh"
    return run_script(
        problem,
        "bash",
        level,
        kind,
        ["bash", str(adapter), str(src), class_for_problem(problem)],
    )


def run_shell(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("shell", problem, kind, "solution.sh", "stub.sh")
    adapter = repo_root() / "langs" / "bash" / "adapter.sh"
    return run_script(
        problem,
        "shell",
        level,
        kind,
        ["bash", str(adapter), str(src), class_for_problem(problem)],
    )


def _pwsh() -> str:
    path = shutil.which("pwsh")
    if path:
        return path
    raise RuntimeError("pwsh not found")


def run_powershell(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("powershell", problem, kind, "solution.ps1", "stub.ps1")
    adapter = repo_root() / "langs" / "powershell" / "adapter.ps1"
    return run_script(
        problem,
        "powershell",
        level,
        kind,
        [
            _pwsh(),
            "-NoProfile",
            "-File",
            str(adapter),
            str(src),
            class_for_problem(problem),
        ],
    )


def _sbcl() -> str:
    path = shutil.which("sbcl")
    if path:
        return path
    raise RuntimeError("sbcl not found")


def _clojure() -> list[str]:
    path = shutil.which("clojure")
    if path:
        help_proc = subprocess.run(
            [path, "-h"],
            check=False,
            capture_output=True,
            text=True,
        )
        blob = f"{help_proc.stdout}\n{help_proc.stderr}"
        if "clj-opt" in blob or "-M[aliases]" in blob:
            return [path, "-M"]
        return [path]
    java = shutil.which("java")
    for jar in (
        "/usr/share/java/clojure.jar",
        "/usr/share/java/clojure-1.11.1.jar",
    ):
        if java and Path(jar).is_file():
            return [java, "-cp", jar, "clojure.main"]
    raise RuntimeError("clojure not found")


def run_clojure(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("clojure", problem, kind, "solution.clj", "stub.clj")
    adapter = repo_root() / "langs" / "clojure" / "adapter.clj"
    return run_script(
        problem,
        "clojure",
        level,
        kind,
        [*_clojure(), str(adapter), str(src), class_for_problem(problem)],
    )


def _gst() -> str:
    path = shutil.which("gst")
    if path:
        return path
    raise RuntimeError("gst not found")


def run_smalltalk(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("smalltalk", problem, kind, "solution.st", "stub.st")
    adapter = repo_root() / "langs" / "smalltalk" / "adapter.st"
    return run_script(
        problem,
        "smalltalk",
        level,
        kind,
        [
            _gst(),
            "-q",
            "--no-user-files",
            str(adapter),
            "-a",
            str(src),
            class_for_problem(problem),
        ],
    )


def run_common_lisp(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("common-lisp", problem, kind, "solution.lisp", "stub.lisp")
    adapter = repo_root() / "langs" / "common-lisp" / "adapter.lisp"
    return run_script(
        problem,
        "common-lisp",
        level,
        kind,
        [_sbcl(), "--script", str(adapter), str(src), class_for_problem(problem)],
    )


def run_groovy(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("groovy", problem, kind, "solution.groovy", "stub.groovy")
    adapter = repo_root() / "langs" / "groovy" / "adapter.groovy"
    return run_script(
        problem,
        "groovy",
        level,
        kind,
        [_groovy(), str(adapter), str(src), class_for_problem(problem)],
    )


def run_octave(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("octave", problem, kind, "solution.m", "stub.m")
    adapter = repo_root() / "langs" / "octave" / "adapter.m"
    return run_script(
        problem,
        "octave",
        level,
        kind,
        [
            _octave(),
            "--quiet",
            "--no-gui",
            "--no-window-system",
            "--no-history",
            "--norc",
            "--path",
            str(adapter.parent),
            str(adapter),
            str(src),
            class_for_problem(problem),
        ],
    )


def run_lua(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("lua", problem, kind, "solution.lua", "stub.lua")
    adapter = repo_root() / "langs" / "lua" / "adapter.lua"
    return run_script(
        problem,
        "lua",
        level,
        kind,
        [_lua(), str(adapter), str(src), class_for_problem(problem)],
    )


def run_php(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("php", problem, kind, "solution.php", "stub.php")
    adapter = repo_root() / "langs" / "php" / "adapter.php"
    return run_script(
        problem,
        "php",
        level,
        kind,
        ["php", str(adapter), str(src), class_for_problem(problem)],
    )


def go_entry(problem: str, kind: str) -> Path:
    return pack_src("go", problem, kind, "solution.go", "stub.go")


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
    return pack_src("rust", problem, kind, "solution.rs", "stub.rs")


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
    return pack_src("java", problem, kind, "solution.java", "stub.java")


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
            raise RuntimeError(f"{src}: {compiled.stderr or compiled.stdout or 'javac failed'}")
        return ["java", "Adapter", cases_path, class_name]

    return run_compiled(problem, "java", level, prepare)


def csharp_entry(problem: str, kind: str) -> Path:
    return pack_src("csharp", problem, kind, "solution.cs", "stub.cs")


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


def fsharp_entry(problem: str, kind: str) -> Path:
    return pack_src("fsharp", problem, kind, "solution.fs", "stub.fs")


def run_fsharp(problem: str, level: int, kind: str = "solution") -> Report:
    src = fsharp_entry(problem, kind)
    fsharp_dir = repo_root() / "langs" / "fsharp"
    class_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(fsharp_dir / "Adapter.fs", tmpdir / "Adapter.fs")
        shutil.copy(fsharp_dir / "honepadrun.fsproj", tmpdir / "honepadrun.fsproj")
        shutil.copy(src, tmpdir / "Solution.fs")
        os.environ["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
        os.environ["DOTNET_NOLOGO"] = "1"
        os.environ["DOTNET_SKIP_FIRST_TIME_EXPERIENCE"] = "1"
        return ["dotnet", "run", "--quiet", "--", cases_path, class_name]

    return run_compiled(problem, "fsharp", level, prepare)


def freepascal_entry(problem: str, kind: str) -> Path:
    return pack_src("freepascal", problem, kind, "solution.pas", "stub.pas")


def _fpc() -> str:
    path = shutil.which("fpc")
    if path:
        return path
    raise RuntimeError("fpc not found")


def run_freepascal(problem: str, level: int, kind: str = "solution") -> Report:
    src = freepascal_entry(problem, kind)
    fpc_dir = repo_root() / "langs" / "freepascal"

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(fpc_dir / "adapter.pas", tmpdir / "adapter.pas")
        shutil.copy(fpc_dir / "minijson.pas", tmpdir / "minijson.pas")
        shutil.copy(src, tmpdir / "solution.pas")
        compiled = subprocess.run(
            [_fpc(), "-O-", "-orun", "adapter.pas"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "fpc compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "freepascal", level, prepare)


def run_typescript(problem: str, level: int, kind: str = "solution") -> Report:
    src = pack_src("typescript", problem, kind, "solution.ts", "stub.ts")
    adapter = repo_root() / "langs" / "javascript" / "adapter.js"
    return run_script(
        problem,
        "typescript",
        level,
        kind,
        ["node", str(adapter), str(src), class_for_problem(problem)],
    )


def kotlin_entry(problem: str, kind: str) -> Path:
    return pack_src("kotlin", problem, kind, "solution.kt", "stub.kt")


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
    return pack_src("cpp", problem, kind, "solution.cpp", "stub.cpp")


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


def c_entry(problem: str, kind: str) -> Path:
    return pack_src("c", problem, kind, "solution.c", "stub.c")


def _cc() -> str:
    for name in ("cc", "gcc", "clang"):
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError("c compiler not found")


def nim_entry(problem: str, kind: str) -> Path:
    return pack_src("nim", problem, kind, "solution.nim", "stub.nim")


def _nim() -> str:
    path = shutil.which("nim")
    if path:
        return path
    raise RuntimeError("nim not found")


def run_nim(problem: str, level: int, kind: str = "solution") -> Report:
    src = nim_entry(problem, kind)
    adapter = repo_root() / "langs" / "nim" / "adapter.nim"

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(adapter, tmpdir / "adapter.nim")
        shutil.copy(src, tmpdir / "solution.nim")
        compiled = subprocess.run(
            [
                _nim(),
                "c",
                "--hints:off",
                "--warnings:off",
                "-o:run",
                "adapter.nim",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "nim compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "nim", level, prepare)


def fortran_entry(problem: str, kind: str) -> Path:
    return pack_src("fortran", problem, kind, "solution.f90", "stub.f90")


def _gfortran() -> str:
    path = shutil.which("gfortran")
    if path:
        return path
    raise RuntimeError("gfortran not found")


def run_fortran(problem: str, level: int, kind: str = "solution") -> Report:
    src = fortran_entry(problem, kind)
    fortran_dir = repo_root() / "langs" / "fortran"

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(fortran_dir / "adapter.f90", tmpdir / "adapter.f90")
        shutil.copy(fortran_dir / "honepad_json.f90", tmpdir / "honepad_json.f90")
        shutil.copy(fortran_dir / "minijson.c", tmpdir / "minijson.c")
        shutil.copy(fortran_dir / "minijson.h", tmpdir / "minijson.h")
        shutil.copy(fortran_dir / "json_bridge.c", tmpdir / "json_bridge.c")
        shutil.copy(src, tmpdir / "solution.f90")
        compiled_c = subprocess.run(
            [_cc(), "-std=c11", "-O0", "-c", "minijson.c", "json_bridge.c"],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled_c.returncode != 0:
            raise RuntimeError(
                compiled_c.stderr or compiled_c.stdout or "c json helper compile failed"
            )
        compiled = subprocess.run(
            [
                _gfortran(),
                "-O0",
                "-o",
                "run",
                "minijson.o",
                "json_bridge.o",
                "honepad_json.f90",
                "solution.f90",
                "adapter.f90",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "gfortran compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "fortran", level, prepare)


def run_c(problem: str, level: int, kind: str = "solution") -> Report:
    src = c_entry(problem, kind)
    c_dir = repo_root() / "langs" / "c"
    ctor_name = class_for_problem(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        shutil.copy(c_dir / "adapter.c", tmpdir / "adapter.c")
        shutil.copy(c_dir / "minijson.h", tmpdir / "minijson.h")
        shutil.copy(c_dir / "minijson.c", tmpdir / "minijson.c")
        shutil.copy(c_dir / "harness.h", tmpdir / "harness.h")
        shutil.copy(src, tmpdir / "solution.c")
        (tmpdir / "ctor.c").write_text(
            '#include "harness.h"\n'
            '#include "solution.c"\n\n'
            f"HonepadTarget *new_target(void) {{ return {ctor_name}_new(); }}\n",
            encoding="utf-8",
        )
        compiled = subprocess.run(
            [
                _cc(),
                "-std=c11",
                "-O0",
                "adapter.c",
                "minijson.c",
                "solution.c",
                "ctor.c",
                "-o",
                "run",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=tmpdir,
        )
        if compiled.returncode != 0:
            raise RuntimeError(compiled.stderr or compiled.stdout or "c compile failed")
        return [str(tmpdir / "run"), cases_path]

    return run_compiled(problem, "c", level, prepare)


def swift_entry(problem: str, kind: str) -> Path:
    return pack_src("swift", problem, kind, "solution.swift", "stub.swift")


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


_RUNNERS = {
    "python3": run_python,
    "javascript": run_javascript,
    "ruby": run_ruby,
    "php": run_php,
    "perl": run_perl,
    "lua": run_lua,
    "tcl": run_tcl,
    "r": run_r,
    "octave": run_octave,
    "groovy": run_groovy,
    "dart": run_dart,
    "elixir": run_elixir,
    "erlang": run_erlang,
    "haskell": run_haskell,
    "ocaml": run_ocaml,
    "scala": run_scala,
    "d": run_d,
    "julia": run_julia,
    "coffeescript": run_coffeescript,
    "bash": run_bash,
    "shell": run_shell,
    "powershell": run_powershell,
    "clojure": run_clojure,
    "common-lisp": run_common_lisp,
    "smalltalk": run_smalltalk,
    "freepascal": run_freepascal,
    "go": run_go,
    "rust": run_rust,
    "java": run_java,
    "typescript": run_typescript,
    "csharp": run_csharp,
    "fsharp": run_fsharp,
    "kotlin": run_kotlin,
    "cpp": run_cpp,
    "c": run_c,
    "fortran": run_fortran,
    "swift": run_swift,
    "nim": run_nim,
}


def run(
    problem: str,
    lang_id: str,
    level: int,
    kind: str = "solution",
) -> Report:
    row = language(lang_id)
    fn = _RUNNERS.get(row["id"])
    if fn is None:
        raise NotImplementedError(
            f"runner for {lang_id} is a factory job (adapter={row.get('adapter')})"
        )
    return fn(problem, level, kind)


def map_call(call: dict[str, Any], naming: str) -> dict[str, Any]:
    mapped = dict(call)
    mapped["m"] = method_name(call["m"], naming)
    return mapped
