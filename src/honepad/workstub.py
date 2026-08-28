"""Slice pack stubs so a work file only shows unlocked methods."""

from __future__ import annotations

from honepad.catalog import language
from honepad.traces import load_cases, method_name

_CLASS = {
    "bank_system": "Simulation",
    "in_memory_database": "InMemoryDatabase",
    "file_storage": "Simulation",
    "workers": "Simulation",
}


def methods_through_level(problem: str, level: int, naming: str) -> set[str]:
    names: set[str] = set()
    for case in load_cases(problem, level):
        for call in case["calls"]:
            names.add(method_name(str(call["m"]), naming))
    return names


def slice_stub(text: str, ext: str, allowed: set[str], class_name: str) -> str:
    if ext == "java":
        return _slice_java(text, allowed, class_name)
    if ext == "py":
        return _slice_python(text, allowed)
    return text


def merge_unlocked_methods(work: str, full: str, ext: str, allowed: set[str]) -> str:
    missing = [name for name in sorted(allowed) if not _declares(work, ext, name)]
    if not missing:
        return work
    if ext == "java":
        extras = "".join(_java_method(full, name) or "" for name in missing)
        return _ensure_java_imports(_insert_before_last_brace(work, extras), full, extras)
    if ext == "py":
        extras = "".join(_python_method(full, name) or "" for name in missing)
        if not extras:
            return work
        return work.rstrip() + "\n\n" + extras.lstrip("\n")
    return work


def class_name_for(problem: str) -> str:
    return _CLASS[problem]


def naming_for(lang_id: str) -> str:
    return str(language(lang_id)["naming"])


def _declares(text: str, ext: str, name: str) -> bool:
    if ext == "java":
        return f"{name}(" in text
    if ext == "py":
        return f"def {name}(" in text
    return name in text


def _slice_java(text: str, allowed: set[str], class_name: str) -> str:
    ctor = _java_method(text, class_name) or ""
    methods = []
    for name in _java_method_order(text):
        if name == class_name or name not in allowed:
            continue
        block = _java_method(text, name)
        if block:
            methods.append(block)
    body = ctor + "".join(methods)
    if not body.endswith("\n"):
        body += "\n"
    return _java_header(text, class_name, body) + body + "}\n"


def _java_header(text: str, class_name: str, body: str) -> str:
    marker = f"public class {class_name}"
    idx = text.find(marker)
    if idx < 0:
        raise ValueError(f"missing {marker}")
    brace = text.find("{", idx)
    preamble_lines = []
    for line in text[:idx].splitlines():
        if line.startswith("import "):
            simple = line.rstrip(";").rsplit(".", 1)[-1]
            if simple not in body:
                continue
        preamble_lines.append(line)
    preamble = "\n".join(preamble_lines).strip()
    class_line = text[idx : brace + 1]
    if preamble:
        return preamble + "\n\n" + class_line + "\n"
    return class_line + "\n"


def _java_method_order(text: str) -> list[str]:
    names: list[str] = []
    i = 0
    while True:
        pub = text.find("public ", i)
        if pub < 0:
            return names
        paren = text.find("(", pub)
        if paren < 0:
            return names
        token = text[pub + len("public ") : paren].split()[-1].strip()
        names.append(token)
        i = paren + 1


def _java_method(text: str, name: str) -> str | None:
    start = _java_method_start(text, name)
    if start is None:
        return None
    pub = text.find("public ", start)
    if pub < 0:
        return None
    body = _brace_block(text, pub)
    return text[start:pub] + body


def _java_method_start(text: str, name: str) -> int | None:
    idx = 0
    needle = f"{name}("
    while True:
        pos = text.find(needle, idx)
        if pos < 0:
            return None
        if pos > 0 and (text[pos - 1].isalnum() or text[pos - 1] == "_"):
            idx = pos + 1
            continue
        pub = text.rfind("public ", 0, pos)
        if pub < 0:
            idx = pos + 1
            continue
        return _include_java_doc(text, pub)


def _include_java_doc(text: str, pub: int) -> int:
    close = text.rfind("*/", 0, pub)
    if close < 0 or text[close + 2 : pub].strip() != "":
        return pub
    open_pos = text.rfind("/**", 0, close)
    if open_pos < 0:
        return pub
    return text.rfind("\n", 0, open_pos) + 1


def _brace_block(text: str, start: int) -> str:
    brace = text.find("{", start)
    depth = 0
    i = brace
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                if end < len(text) and text[end] == "\n":
                    end += 1
                return text[start:end]
        i += 1
    raise ValueError("unbalanced braces")


def _ensure_java_imports(work: str, full: str, extras: str) -> str:
    needed = []
    for line in full.splitlines():
        if not line.startswith("import "):
            continue
        simple = line.rstrip(";").rsplit(".", 1)[-1]
        if simple in extras and line not in work:
            needed.append(line)
    if not needed:
        return work
    marker = "public class "
    idx = work.find(marker)
    if idx < 0:
        return "\n".join(needed) + "\n\n" + work
    return work[:idx] + "\n".join(needed) + "\n\n" + work[idx:]


def _insert_before_last_brace(text: str, extra: str) -> str:
    if not extra:
        return text
    close = text.rfind("}")
    if close < 0:
        return text + extra
    prefix = text[:close].rstrip() + "\n\n"
    return prefix + extra.lstrip("\n") + "}\n"


def _slice_python(text: str, allowed: set[str]) -> str:
    header = _python_header(text)
    init = _python_method(text, "__init__") or ""
    parts = [header.rstrip(), init.rstrip()]
    for name in _python_method_order(text):
        if name in {"__init__", "__class__"} or name not in allowed:
            continue
        block = _python_method(text, name)
        if block:
            parts.append(block.rstrip())
    return "\n\n".join(p for p in parts if p) + "\n"


def _python_header(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("class "):
            return line + "\n"
    raise ValueError("missing class line")


def _python_method_order(text: str) -> list[str]:
    names: list[str] = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("def "):
            names.append(stripped[4:].split("(")[0])
    return names


def _python_method(text: str, name: str) -> str | None:
    lines = text.splitlines(keepends=True)
    start = None
    indent = ""
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if stripped.startswith(f"def {name}("):
            start = i
            indent = line[: len(line) - len(stripped)]
            break
    if start is None:
        return None
    end = len(lines)
    for j in range(start + 1, len(lines)):
        line = lines[j]
        if not line.strip():
            continue
        cur = line[: len(line) - len(line.lstrip())]
        if line.lstrip().startswith("def ") and len(cur) <= len(indent):
            end = j
            break
        if line.startswith("class ") and not line.startswith(indent):
            end = j
            break
    return "".join(lines[start:end])
