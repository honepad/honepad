"""Run traces against a language pack.

The per-language knowledge lives in ``langs/<id>/meta.json`` under ``run``; see
``honepad.packspec`` for the schema. This module is the engine that executes a
recipe and turns adapter output into a Report, plus the few resolvers that a
JSON recipe cannot express.
"""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from honepad import packspec
from honepad.catalog import language, repo_root
from honepad.traces import load_cases, method_name
from honepad.workstub import class_name_for

RUN_TIMEOUT_S = 30
COMPILE_TIMEOUT_S = 120


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
    debug: str = ""

    @property
    def ok(self) -> bool:
        return not self.failed


# --------------------------------------------------------------------------
# Sources
# --------------------------------------------------------------------------


def pack_src(lang_id: str, problem: str, kind: str, solution_name: str, stub_name: str) -> Path:
    if kind == "work":
        from honepad.session import work_src

        path = work_src(problem, lang_id)
        if path.is_symlink():
            raise RuntimeError(f"work file is a symlink: {path}")
        if not path.is_file():
            raise FileNotFoundError(f"work file missing: {path}")
        return path
    pack = repo_root() / "langs" / lang_id / "problems" / problem
    return pack / (solution_name if kind == "solution" else stub_name)


def spec_src(lang_id: str, problem: str, kind: str, spec: dict[str, Any]) -> Path:
    return pack_src(lang_id, problem, kind, str(spec["solution"]), str(spec["stub"]))


# --------------------------------------------------------------------------
# Adapter output
# --------------------------------------------------------------------------


def _values_differ(actual: Any, expected: Any) -> bool:
    if expected is True or expected is False or expected is None:
        return actual is not expected
    return actual != expected


def _extract_report_payload(stdout: str, lang_id: str) -> tuple[dict[str, Any], str]:
    text = stdout.rstrip("\n")
    idx = text.rfind("{")
    while idx >= 0:
        try:
            payload = json.loads(text[idx:])
        except json.JSONDecodeError:
            idx = text.rfind("{", 0, idx)
            continue
        if isinstance(payload, dict) and "passed" in payload:
            return payload, text[:idx]
        idx = text.rfind("{", 0, idx)
    raise RuntimeError(f"{lang_id} adapter produced invalid JSON")


def report_from_proc(
    proc: subprocess.CompletedProcess[str],
    problem: str,
    lang_id: str,
    level: int,
) -> Report:
    if not proc.stdout.strip():
        raise RuntimeError(proc.stderr or f"{lang_id} adapter produced no output")
    payload, debug = _extract_report_payload(proc.stdout, lang_id)
    cases = {str(case["id"]): case for case in load_cases(problem, level)}
    failed: list[Fail] = []
    raw_failed = payload.get("failed", [])
    if not isinstance(raw_failed, list):
        raise RuntimeError(f"{lang_id} adapter produced invalid JSON")
    for row in raw_failed:
        if not isinstance(row, dict):
            raise RuntimeError(f"{lang_id} adapter produced invalid JSON")
        args = row.get("args", row.get("a"))
        if not isinstance(args, list):
            case = cases.get(str(row["case"]))
            idx = int(row["index"])
            calls = case["calls"] if case is not None else []
            if 0 <= idx < len(calls):
                args = list(calls[idx]["a"])
            else:
                args = []
        failed.append(
            Fail(row["case"], row["index"], row["method"], args, row["expected"], row["actual"])
        )
    passed = int(payload.get("passed", 0))
    if passed + len(failed) != len(cases):
        raise RuntimeError(
            f"{lang_id} adapter report count mismatch: {passed + len(failed)} != {len(cases)}"
        )
    if proc.returncode != 0 and not failed:
        detail = (proc.stderr or "").strip() or f"{lang_id} adapter exited {proc.returncode}"
        raise RuntimeError(detail)
    return Report(problem, lang_id, level, passed, failed, debug=debug)


# --------------------------------------------------------------------------
# Processes
# --------------------------------------------------------------------------


def run_prepare_cmd(
    argv: list[str],
    cwd: Path | None = None,
    lang_id: str = "",
    timeout: float = COMPILE_TIMEOUT_S,
    src: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        raise RuntimeError(f"{lang_id}: {argv[0]} not on PATH") from exc
    except subprocess.TimeoutExpired as exc:
        prefix = f"{src}: " if src is not None else ""
        raise RuntimeError(f"{prefix}{lang_id} timed out after {timeout}s") from exc


def compile_fail(src: Path, proc: subprocess.CompletedProcess[str], fallback: str) -> RuntimeError:
    return RuntimeError(f"{src}: {proc.stderr or proc.stdout or fallback}")


def run_compiled(
    problem: str,
    lang_id: str,
    level: int,
    prepare: Callable[[Path, str], list[str]],
    src: Path | None = None,
) -> Report:
    """prepare(tmpdir: Path, cases_path: str) -> list[str]  (argv to run in tmpdir)."""
    cases = load_cases(problem, level)
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        cases_path = tmpdir / "cases.json"
        cases_path.write_text(json.dumps(cases), encoding="utf-8")
        argv = prepare(tmpdir, str(cases_path))
        proc = run_prepare_cmd(argv, tmpdir, lang_id, timeout=RUN_TIMEOUT_S, src=src)
    return report_from_proc(proc, problem, lang_id, level)


def run_script(
    problem: str,
    lang_id: str,
    level: int,
    kind: str,
    argv: list[str],
    src: Path | None = None,
) -> Report:
    cases = load_cases(problem, level)
    with tempfile.TemporaryDirectory() as tmp:
        cases_path = Path(tmp) / "cases.json"
        cases_path.write_text(json.dumps(cases), encoding="utf-8")
        proc = run_prepare_cmd(
            [*argv, str(cases_path)],
            lang_id=lang_id,
            timeout=RUN_TIMEOUT_S,
            src=src,
        )
    return report_from_proc(proc, problem, lang_id, level)


# --------------------------------------------------------------------------
# Recipe execution
# --------------------------------------------------------------------------


def run_spec_script(
    problem: str, lang_id: str, level: int, kind: str, spec: dict[str, Any]
) -> Report:
    src = spec_src(lang_id, problem, kind, spec)
    ctx = packspec.context(lang_id, class_name=class_name_for(problem), src=src)
    tool = packspec.resolve_tool(spec, lang_id)
    argv = packspec.render_argv(list(spec["argv"]), ctx, tool)
    return run_script(problem, lang_id, level, kind, argv, src=src)


def run_spec_compiled(
    problem: str, lang_id: str, level: int, kind: str, spec: dict[str, Any]
) -> Report:
    src = spec_src(lang_id, problem, kind, spec)
    class_name = class_name_for(problem)

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        ctx = packspec.context(
            lang_id, class_name=class_name, src=src, cases=cases_path, tmpdir=tmpdir
        )
        packspec.lay_out(spec, tmpdir, src, ctx)
        packspec.prepare_env(spec, lang_id)
        for step in spec.get("steps", []):
            tool = packspec.resolve_tool(step, lang_id)
            built = run_prepare_cmd(packspec.step_argv(step, ctx, tool), tmpdir, lang_id)
            if built.returncode != 0:
                raise compile_fail(src, built, str(step.get("fail", "compile failed")))
        return packspec.render_argv(list(spec["argv"]), ctx, packspec.resolve_tool(spec, lang_id))

    return run_compiled(problem, lang_id, level, prepare, src=src)


# --------------------------------------------------------------------------
# Python 3: imported in a child interpreter, not shelled out to an adapter
# --------------------------------------------------------------------------


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
    except KeyboardInterrupt:
        raise
    except BaseException as exc:  # noqa: BLE001 - user pack load
        raise RuntimeError(_format_load_error(path, exc)) from exc


def _format_load_error(path: Path, exc: BaseException) -> str:
    name = type(exc).__name__
    msg = getattr(exc, "msg", None) or str(exc).strip()
    lineno = getattr(exc, "lineno", None)
    if lineno is not None:
        return f"{path}: {name}: {msg} (line {lineno})"
    if msg and msg != name:
        return f"{path}: {name}: {msg}"
    return f"{path}: {name}"


def python_entry(problem: str, kind: str) -> Path:
    return pack_src("python3", problem, kind, "solution.py", "stub.py")


def run_python_body(problem: str, level: int, kind: str = "solution") -> Report:
    cases = load_cases(problem, level)
    differ = _values_differ
    cls = _load_python_class(python_entry(problem, kind), class_name_for(problem))
    failed: list[Fail] = []
    passed = 0
    for case in cases:
        for i, call in enumerate(case["calls"]):
            method = call["m"]
            args = list(call["a"])
            expected = call["e"]
            try:
                if i == 0:
                    obj = cls()
                fn = getattr(obj, method)
                actual = fn(*args)
            except KeyboardInterrupt:
                raise
            except BaseException as exc:  # noqa: BLE001 - user pack
                failed.append(
                    Fail(case["id"], i, method, args, expected, f"exc:{type(exc).__name__}")
                )
                break
            if differ(actual, expected):
                failed.append(Fail(case["id"], i, method, args, expected, actual))
                break
        else:
            passed += 1
    return Report(problem, "python3", level, passed, failed)


def run_python(problem: str, level: int, kind: str = "solution") -> Report:
    src = python_entry(problem, kind)
    env = os.environ.copy()
    src_dir = str(repo_root() / "src")
    prior = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = src_dir if not prior else src_dir + os.pathsep + prior
    try:
        proc = subprocess.run(
            [sys.executable, "-m", "honepad._pyrun", problem, str(level), kind],
            check=False,
            capture_output=True,
            text=True,
            timeout=RUN_TIMEOUT_S,
            env=env,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"{src}: python3 timed out after {RUN_TIMEOUT_S}s") from exc
    return report_from_proc(proc, problem, "python3", level)


_HOOK_RUNNERS: dict[str, Callable[[str, int, str], Report]] = {"python": run_python}


# --------------------------------------------------------------------------
# Resolvers a JSON recipe cannot express
# --------------------------------------------------------------------------


def _coursier_bins() -> list[Path]:
    home = Path.home()
    return [
        home / "Library" / "Application Support" / "Coursier" / "bin",
        home / ".local" / "share" / "coursier" / "bin",
    ]


def _prepend_path(folder: Path) -> None:
    text = str(folder)
    current = os.environ.get("PATH", "")
    parts = current.split(os.pathsep) if current else []
    if text and text not in parts:
        os.environ["PATH"] = text + os.pathsep + current


def _tool(name: str) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    for folder in _coursier_bins():
        cand = folder / name
        if cand.is_file() and os.access(cand, os.X_OK):
            return str(cand)
    return None


def _ensure_scala() -> None:
    script = repo_root() / "factory" / "scripts" / "ensure-scala.sh"
    subprocess.run(["bash", str(script)], check=False)
    for folder in _coursier_bins():
        if (folder / "scalac").is_file():
            _prepend_path(folder)
            return


def _scala_tool(name: str) -> str:
    found = _tool(name)
    if found:
        return found
    _ensure_scala()
    found = _tool(name)
    if found:
        return found
    raise RuntimeError(f"{name} not found")


@packspec.tool_hook("scalac")
def _scalac() -> list[str]:
    """Scala installs through Coursier, whose bin dir is not always on PATH."""
    return [_scala_tool("scalac")]


@packspec.tool_hook("scala")
def _scala() -> list[str]:
    return [_scala_tool("scala")]


@packspec.tool_hook("clojure")
def _clojure() -> list[str]:
    """The CLI needs -M to run a script; the older launcher and the jar do not."""
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


@packspec.env_hook("dotnet")
def _prepare_dotnet_env() -> None:
    os.environ["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
    os.environ["DOTNET_NOLOGO"] = "1"
    os.environ["DOTNET_SKIP_FIRST_TIME_EXPERIENCE"] = "1"
    # net8.0 apphost on a later SDK (Homebrew 10) needs the host dir and roll-forward.
    os.environ["DOTNET_ROLL_FORWARD"] = "LatestMajor"
    if os.environ.get("DOTNET_ROOT"):
        return
    path = shutil.which("dotnet")
    if not path:
        return
    resolved = Path(path).resolve().parent
    for candidate in (resolved, resolved.parent / "libexec", resolved.parent):
        if (candidate / "host").is_dir():
            os.environ["DOTNET_ROOT"] = str(candidate)
            return


# --------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------


def _run_pack(problem: str, lang_id: str, level: int, kind: str) -> Report:
    spec = packspec.run_spec(lang_id)
    if spec is None:
        raise NotImplementedError(f"no run recipe for {lang_id}")
    if spec["kind"] == "hook":
        fn = _HOOK_RUNNERS.get(str(spec["hook"]))
        if fn is None:
            raise NotImplementedError(f"{lang_id}: unknown run hook {spec['hook']}")
        return fn(problem, level, kind)
    if spec["kind"] == "script":
        return run_spec_script(problem, lang_id, level, kind, spec)
    return run_spec_compiled(problem, lang_id, level, kind, spec)


class _PackRunners:
    """The runner table, keyed by catalog id, backed by the pack recipes.

    Reads like the hand-written dict it replaced (``lang in _RUNNERS``,
    ``len(_RUNNERS)``, ``_RUNNERS[lang](problem, level, kind)``) so callers and
    the catalog completeness tests do not care that it is data now.
    """

    def _ids(self) -> list[str]:
        return packspec.runnable_ids()

    def __contains__(self, lang_id: object) -> bool:
        return isinstance(lang_id, str) and lang_id in self._ids()

    def __iter__(self):
        return iter(self._ids())

    def __len__(self) -> int:
        return len(self._ids())

    def __getitem__(self, lang_id: str) -> Callable[..., Report]:
        if lang_id not in self:
            raise KeyError(lang_id)

        def call(problem: str, level: int, kind: str = "solution") -> Report:
            return _run_pack(problem, lang_id, level, kind)

        return call

    def get(self, lang_id: str, default: Any = None) -> Any:
        return self[lang_id] if lang_id in self else default

    def keys(self) -> list[str]:
        return self._ids()


_RUNNERS = _PackRunners()


def run(problem: str, lang_id: str, level: int, kind: str = "solution") -> Report:
    row = language(lang_id)
    if row["id"] not in _RUNNERS:
        raise NotImplementedError(
            f"runner for {lang_id} is a factory job (adapter={row.get('adapter')})"
        )
    return _run_pack(problem, str(row["id"]), level, kind)


def map_call(call: dict[str, Any], naming: str) -> dict[str, Any]:
    mapped = dict(call)
    mapped["m"] = method_name(call["m"], naming)
    return mapped
