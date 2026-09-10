#!/usr/bin/env python3
"""Partition pytest node ids so CI shards do not share tests.

Default is unit. Token routing applies to test_traces.py. A skipif
on which("bin") fails closed when the assigned shard is outside
BINARY_TO_SHARDS[bin] (set membership, not 1:1).

Naive ``pytest -k java`` also matches javascript. ``-k c`` matches
csharp and clojure. This script assigns by underscore-bounded tokens
and exact overrides, then runs the selected node ids.
"""

from __future__ import annotations

import argparse
import ast
import os
import subprocess
import sys
from collections.abc import Iterable
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _env() -> dict[str, str]:
    env = os.environ.copy()
    src = str(ROOT / "src")
    current = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = src if not current else src + os.pathsep + current
    return env


SHARDS = ("unit", "script", "compiled", "jvm", "stats")

# Longest first so javascript wins over java and csharp wins over c.
_LANG_TO_SHARD: dict[str, str] = {
    "javascript": "script",
    "typescript": "script",
    "coffeescript": "script",
    "freepascal": "compiled",
    "common_lisp": "script",
    "powershell": "script",
    "smalltalk": "script",
    "clojure": "script",
    "fortran": "compiled",
    "haskell": "compiled",
    "kotlin": "jvm",
    "octave": "stats",
    "elixir": "script",
    "erlang": "script",
    "groovy": "script",
    "csharp": "compiled",
    "fsharp": "compiled",
    "scala": "jvm",
    "swift": "compiled",
    "julia": "script",
    "dart": "script",
    "perl": "script",
    "ruby": "script",
    "rust": "compiled",
    "lisp": "script",
    "php": "script",
    "lua": "script",
    "tcl": "script",
    "nim": "compiled",
    "cpp": "compiled",
    "bash": "script",
    "shell": "script",
    "java": "jvm",
    "ocaml": "compiled",
    "js": "script",
    "go": "compiled",
    "c": "compiled",
    "d": "compiled",
    "r": "stats",
}
_TOKENS = tuple(sorted(_LANG_TO_SHARD, key=len, reverse=True))
_IGNORE = frozenset({"python3", "python"})

# Mixed names, or names that do not contain a language token.
_OVERRIDES: dict[str, str] = {
    "test_script_stubs_fail": "script",
    "test_prove_python3_and_go_all_problems": "compiled",
    "test_file_storage_python_and_js": "script",
    "test_workers_python_and_js": "script",
}

# Shards that install each skipif binary. Set membership, not 1:1.
BINARY_TO_SHARDS: dict[str, frozenset[str]] = {
    "javac": frozenset({"unit", "script", "jvm"}),
    "node": frozenset(SHARDS),
    "ruby": frozenset(SHARDS),
    "bash": frozenset(SHARDS),
    "cargo": frozenset({"compiled"}),
    "go": frozenset({"compiled"}),
    "dotnet": frozenset({"compiled"}),
    "cc": frozenset({"compiled"}),
    "gcc": frozenset({"compiled"}),
    "gst": frozenset({"script"}),
    "php": frozenset({"script"}),
    "perl": frozenset({"script"}),
    "lua": frozenset({"script"}),
    "tclsh": frozenset({"script"}),
    "groovy": frozenset({"script"}),
    "dart": frozenset({"script"}),
    "elixir": frozenset({"script"}),
    "escript": frozenset({"script"}),
    "julia": frozenset({"script"}),
    "coffee": frozenset({"script"}),
    "sbcl": frozenset({"script"}),
    "clojure": frozenset({"script"}),
    "pwsh": frozenset({"script"}),
    "Rscript": frozenset({"stats"}),
    "octave": frozenset({"stats"}),
    "octave-cli": frozenset({"stats"}),
}
_MVN_UNIT_ALLOW = frozenset(
    {
        "test_java_junit_l1_stub_fails_without_npe",
        "test_java_junit_project_compiles",
        "test_java_junit_l2_project_compiles",
    }
)


def _log(line: str) -> None:
    print(line, flush=True)


def function_name(nodeid: str) -> str:
    name = nodeid.rsplit("::", 1)[-1]
    return name.split("[", 1)[0]


def node_path(nodeid: str) -> str:
    return nodeid.split("::", 1)[0].replace("\\", "/")


def langs_in(func_name: str) -> list[str]:
    body = func_name.removeprefix("test_")
    padded = f"_{body}_"
    found: list[str] = []
    remaining = padded
    for token in _TOKENS:
        needle = f"_{token}_"
        if needle in remaining:
            found.append(token)
            remaining = remaining.replace(needle, "_")
    return [token for token in found if token not in _IGNORE]


def _session_skipif_toolchain(path: str, func: str) -> bool:
    """Session skipif tests that need a binary only some shards install.

    Maven JUnit tests stay on unit; installing mvn is a larger image change.
    """
    if not path.endswith("test_session.py"):
        return False
    if func == "test_work_compile_error_prints_c_work_path":
        return True
    return func.startswith("test_submit_rejects_") and "exact_count_fake_json" in func


def _shard_from_tokens(nodeid: str, func: str) -> str:
    shards = {_LANG_TO_SHARD[token] for token in langs_in(func)}
    if not shards:
        return "unit"
    if len(shards) > 1:
        raise ValueError(f"{nodeid}: mixed shards {sorted(shards)}")
    return next(iter(shards))


def assign_shard(nodeid: str) -> str:
    path = node_path(nodeid)
    func = function_name(nodeid)
    if func in _OVERRIDES:
        return _OVERRIDES[func]
    if path.endswith("test_traces.py") or _session_skipif_toolchain(path, func):
        return _shard_from_tokens(nodeid, func)
    return "unit"


def _is_skipif_decorator(node: ast.expr) -> bool:
    target = node.func if isinstance(node, ast.Call) else node
    if isinstance(target, ast.Name):
        return target.id == "skipif"
    if isinstance(target, ast.Attribute):
        return target.attr == "skipif"
    return False


def _is_which_call(func: ast.expr) -> bool:
    if isinstance(func, ast.Name):
        return func.id == "which"
    if isinstance(func, ast.Attribute):
        return func.attr == "which"
    return False


def skipif_which_binaries(source: str) -> dict[str, list[str]]:
    """Map test function names to binaries named in skipif(which(...))."""
    tree = ast.parse(source)
    found: dict[str, list[str]] = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef):
            continue
        binaries: list[str] = []
        for dec in node.decorator_list:
            if not _is_skipif_decorator(dec):
                continue
            for child in ast.walk(dec):
                if not isinstance(child, ast.Call) or not _is_which_call(child.func):
                    continue
                if not child.args:
                    continue
                arg = child.args[0]
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                    binaries.append(arg.value)
        if binaries:
            found[node.name] = binaries
    return found


def check_skipif_assignment(nodeid: str, assigned: str, binaries: Iterable[str]) -> None:
    """Exit 1 when a skipif binary is missing or assigned off its shard set."""
    func = function_name(nodeid)
    for binary in binaries:
        if binary == "mvn" and func in _MVN_UNIT_ALLOW and assigned == "unit":
            continue
        allowed = BINARY_TO_SHARDS.get(binary)
        if allowed is None:
            _log(f"FAIL: {nodeid} binary={binary} assigned={assigned} allowed=missing")
            raise SystemExit(1)
        if assigned not in allowed:
            _log(f"FAIL: {nodeid} binary={binary} assigned={assigned} allowed={sorted(allowed)}")
            raise SystemExit(1)


def _check_skipif_fail_closed(nodeids: list[str]) -> None:
    cache: dict[str, dict[str, list[str]]] = {}
    for nodeid in nodeids:
        path = node_path(nodeid)
        if path not in cache:
            full = ROOT / path
            if full.is_file():
                cache[path] = skipif_which_binaries(full.read_text(encoding="utf-8"))
            else:
                cache[path] = {}
        binaries = cache[path].get(function_name(nodeid), ())
        if binaries:
            check_skipif_assignment(nodeid, assign_shard(nodeid), binaries)


def collect_nodeids() -> list[str]:
    _log("DO: pytest --collect-only")
    proc = subprocess.run(
        [sys.executable, "-m", "pytest", "--collect-only", "-q"],
        cwd=ROOT,
        env=_env(),
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode not in (0,):
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode or 1)
    nodeids: list[str] = []
    for line in proc.stdout.splitlines():
        text = line.strip()
        if not text or text.startswith("="):
            continue
        if "::" not in text:
            continue
        if text[0].isdigit():
            continue
        nodeids.append(text)
    if not nodeids:
        _log("FAIL: collected 0 tests")
        raise SystemExit(1)
    _log(f"OK: collected {len(nodeids)}")
    return nodeids


def partition(nodeids: list[str]) -> dict[str, list[str]]:
    buckets: dict[str, list[str]] = {name: [] for name in SHARDS}
    for nodeid in nodeids:
        buckets[assign_shard(nodeid)].append(nodeid)
    return buckets


def check_partition(nodeids: list[str]) -> dict[str, list[str]]:
    buckets = partition(nodeids)
    _check_skipif_fail_closed(nodeids)
    empty = [name for name, rows in buckets.items() if not rows]
    if empty:
        _log(f"FAIL: empty shards {empty}")
        raise SystemExit(1)
    assigned = sum(len(rows) for rows in buckets.values())
    if assigned != len(nodeids):
        _log(f"FAIL: assigned {assigned} of {len(nodeids)}")
        raise SystemExit(1)
    for name, rows in buckets.items():
        _log(f"OK: shard {name} n={len(rows)}")
    return buckets


def run_shard(name: str, extra: list[str]) -> int:
    if name not in SHARDS:
        _log(f"FAIL: unknown shard {name}")
        return 1
    buckets = check_partition(collect_nodeids())
    selected = buckets[name]
    _log(f"DO: pytest shard={name} n={len(selected)}")
    cmd = [sys.executable, "-m", "pytest", *selected, *extra]
    result = subprocess.run(cmd, cwd=ROOT, env=_env(), check=False)
    if result.returncode == 0:
        _log(f"DONE: ok=true shard={name}")
    else:
        _log(f"DONE: ok=false shard={name} rc={result.returncode}")
    return result.returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--list", choices=SHARDS)
    parser.add_argument("--run", choices=SHARDS)
    parser.add_argument("pytest_args", nargs="*")
    args = parser.parse_args(argv)
    if args.check:
        _log("PLAN: verify shard partition")
        check_partition(collect_nodeids())
        _log("DONE: ok=true")
        return 0
    if args.list:
        _log(f"PLAN: list shard {args.list}")
        for nodeid in check_partition(collect_nodeids())[args.list]:
            print(nodeid, flush=True)
        _log("DONE: ok=true")
        return 0
    if args.run:
        _log(f"PLAN: run shard {args.run}")
        extra = args.pytest_args
        if extra[:1] == ["--"]:
            extra = extra[1:]
        return run_shard(args.run, extra)
    parser.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
