"""Declarative language pack recipes.

Every implemented pack describes its own toolchain in ``langs/<id>/meta.json``
under a ``run`` key, so adding a language is a directory, an adapter and a JSON
block -- no Python. ``honepad.runner`` executes what this module loads.

Two kinds cover every pack:

``script``
    An interpreter runs the pack adapter, which loads the candidate source and
    replays the traces. ``argv`` is the command; the cases file is appended.

``compiled``
    ``copy`` and ``write`` lay out a temp dir, ``steps`` build it, and ``argv``
    runs the artifact. Here ``argv`` names the cases file itself, because the
    position differs per toolchain.

``hook``
    The escape hatch for a pack that is neither, naming a Python runner by key.
    Only Python 3 uses it: honepad imports that pack in a child interpreter
    rather than shelling out to an adapter.

Tokens substituted in argv entries and in ``write`` bodies:

===================  =======================================================
``{{class}}``        class the problem expects (``Simulation``, ...)
``{{src}}``          absolute path of the candidate source
``{{src_name}}``     that source's file name
``{{cases}}``        absolute path of the traces file
``{{tmp}}``          build directory (``compiled`` only)
``{{pack}}``         ``langs/<id>``
``{{langs}}``        ``langs``, for packs that borrow another pack's adapter
``{{pathsep}}``      ``os.pathsep``
``{{tool}}``         the resolved tool, expanded in place as one or more words
===================  =======================================================
"""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

from honepad.catalog import repo_root

KINDS = ("script", "compiled", "hook")

# Resolvers for the two toolchains that cannot be found by name alone.
# Everything else is a PATH lookup driven by the JSON.
_TOOL_HOOKS: dict[str, Any] = {}
_ENV_HOOKS: dict[str, Any] = {}


def tool_hook(name: str):
    """Register a resolver returning the argv for ``{{tool}}``."""

    def wrap(fn):
        _TOOL_HOOKS[name] = fn
        return fn

    return wrap


def env_hook(name: str):
    """Register a callback that prepares os.environ before a build runs."""

    def wrap(fn):
        _ENV_HOOKS[name] = fn
        return fn

    return wrap


def pack_dir(lang_id: str) -> Path:
    return repo_root() / "langs" / lang_id


# Pack metadata is read on every `lang in _RUNNERS` check, so keep it in memory.
# Keyed by (path, mtime) so an edited pack is picked up without a restart.
_META_CACHE: dict[tuple[str, int], dict[str, Any]] = {}


def load_meta(lang_id: str) -> dict[str, Any]:
    path = pack_dir(lang_id) / "meta.json"
    try:
        key = (str(path), path.stat().st_mtime_ns)
    except OSError:
        key = None
    if key is not None and key in _META_CACHE:
        return _META_CACHE[key]
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"{path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError(f"{path} must be a JSON object")
    if key is not None:
        _META_CACHE[key] = payload
    return payload


def run_spec(lang_id: str) -> dict[str, Any] | None:
    """The pack's run recipe, or None when the pack has no runner yet."""
    spec = load_meta(lang_id).get("run")
    if spec is None:
        return None
    if not isinstance(spec, dict):
        raise ValueError(f"{lang_id}: run must be a JSON object")
    kind = spec.get("kind")
    if kind not in KINDS:
        raise ValueError(f"{lang_id}: run.kind must be one of {', '.join(KINDS)}")
    for key in ("solution", "stub"):
        if key not in spec:
            raise ValueError(f"{lang_id}: run.{key} is required")
    if kind == "hook":
        if not spec.get("hook"):
            raise ValueError(f"{lang_id}: run.hook is required for kind=hook")
        return spec
    if not isinstance(spec.get("argv"), list) or not spec["argv"]:
        raise ValueError(f"{lang_id}: run.argv must be a non-empty list")
    return spec


def runnable_ids() -> list[str]:
    """Catalog ids whose pack ships a run recipe, in catalog order."""
    from honepad.catalog import language_ids

    ids: list[str] = []
    for lang_id in language_ids():
        if not (pack_dir(lang_id) / "meta.json").is_file():
            continue
        if run_spec(lang_id) is not None:
            ids.append(lang_id)
    return ids


def required_tools(lang_id: str) -> list[list[str]]:
    """Binaries a session needs before it is worth starting.

    Each entry is a group of interchangeable names -- ``cc``, ``gcc`` and
    ``clang`` all satisfy the C pack -- so a group counts as present when any
    one of its members is on PATH. A bare string is a group of one.
    """
    spec = run_spec(lang_id)
    if spec is None:
        return []
    groups: list[list[str]] = []
    for entry in spec.get("requires", []):
        names = entry if isinstance(entry, list) else [entry]
        groups.append([str(name) for name in names])
    return groups


def missing_tools(lang_id: str) -> list[str]:
    """The first name of every required group this machine cannot satisfy."""
    return [
        group[0]
        for group in required_tools(lang_id)
        if group and not any(shutil.which(name) for name in group)
    ]


def on_missing_tools(lang_id: str) -> str:
    """What starting a session should do when the toolchain is absent.

    ``warn`` by default: a work file and a spec are useful before the compiler
    is installed, and `run` fails clearly enough on its own. A pack sets
    ``block`` when starting without its toolchain is not worth the clock --
    Java does, because a missing JDK used to surface as a confusing javac error.
    """
    spec = run_spec(lang_id)
    if spec is None:
        return "warn"
    policy = str(spec.get("on_missing_tools", "warn"))
    if policy not in {"warn", "block"}:
        raise ValueError(f"{lang_id}: run.on_missing_tools must be warn or block")
    return policy


def _first_word(candidate: Any) -> str:
    return candidate[0] if isinstance(candidate, list) else str(candidate)


def resolve_tool(spec: dict[str, Any], lang_id: str) -> list[str]:
    """Argv for ``{{tool}}``.

    A single bare candidate is passed through so a missing binary surfaces as
    the runner's "not on PATH" message. Anything with alternatives or its own
    error text is looked up here, because the caller has to know which one won.
    """
    hook = spec.get("tool_hook")
    if hook is not None:
        fn = _TOOL_HOOKS.get(str(hook))
        if fn is None:
            raise ValueError(f"{lang_id}: unknown tool_hook {hook}")
        return list(fn())
    candidates = spec.get("tool")
    if not candidates:
        return []
    if not isinstance(candidates, list):
        raise ValueError(f"{lang_id}: run tool must be a list")
    message = spec.get("tool_error")
    if len(candidates) == 1 and message is None and not isinstance(candidates[0], list):
        return [str(candidates[0])]
    for candidate in candidates:
        found = shutil.which(_first_word(candidate))
        if found:
            rest = candidate[1:] if isinstance(candidate, list) else []
            return [found, *(str(word) for word in rest)]
    raise RuntimeError(str(message or f"{_first_word(candidates[0])} not found"))


def prepare_env(spec: dict[str, Any], lang_id: str) -> None:
    name = spec.get("env_hook")
    if name is None:
        return
    fn = _ENV_HOOKS.get(str(name))
    if fn is None:
        raise ValueError(f"{lang_id}: unknown env_hook {name}")
    fn()


def context(
    lang_id: str,
    *,
    class_name: str,
    src: Path,
    cases: str = "",
    tmpdir: Path | None = None,
) -> dict[str, str]:
    langs = repo_root() / "langs"
    return {
        "class": class_name,
        "src": str(src),
        "src_name": src.name,
        "cases": cases,
        "tmp": str(tmpdir) if tmpdir is not None else "",
        "pack": str(langs / lang_id),
        "langs": str(langs),
        "pathsep": os.pathsep,
    }


def substitute(text: str, ctx: dict[str, str]) -> str:
    for key, value in ctx.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def render_argv(argv: list[str], ctx: dict[str, str], tool: list[str]) -> list[str]:
    out: list[str] = []
    for word in argv:
        if word == "{{tool}}":
            out.extend(tool)
            continue
        out.append(substitute(str(word), ctx))
    return out


def step_argv(step: dict[str, Any], ctx: dict[str, str], tool: list[str]) -> list[str]:
    """A step's argv, letting a toolchain pick its own flags.

    ``argv_by_tool`` keys match the front of the resolved binary's name, with
    ``*`` as the fallback: gdc spells its output flag differently from dmd.
    """
    table = step.get("argv_by_tool")
    if table is None:
        return render_argv(list(step["argv"]), ctx, tool)
    name = Path(tool[0]).name.lower() if tool else ""
    for key, argv in table.items():
        if key != "*" and name.startswith(key):
            return render_argv(list(argv), ctx, tool)
    if "*" not in table:
        raise ValueError(f"argv_by_tool has no match for {name} and no '*' fallback")
    return render_argv(list(table["*"]), ctx, tool)


def lay_out(spec: dict[str, Any], tmpdir: Path, src: Path, ctx: dict[str, str]) -> None:
    """Copy the pack's support files and write its generated ones."""
    for dest, source in spec.get("copy", {}).items():
        target = tmpdir / substitute(str(dest), ctx)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(Path(substitute(str(source), ctx)), target)
    target = tmpdir / substitute(str(spec.get("src_as", "{{src_name}}")), ctx)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, target)
    for dest, body in spec.get("write", {}).items():
        target = tmpdir / substitute(str(dest), ctx)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(substitute(str(body), ctx), encoding="utf-8")
