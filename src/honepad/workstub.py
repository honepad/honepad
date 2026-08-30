"""Slice pack stubs so a work file only shows unlocked methods."""

from __future__ import annotations

import re

from honepad.catalog import language
from honepad.traces import load_cases, method_name

_API_IDENT = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\(")
_RUBY_DEF = re.compile(r"^(\s*)def ([A-Za-z_][A-Za-z0-9_?!]*)\b")

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
    if ext in {"js", "ts"}:
        return _slice_js(text, allowed, class_name)
    if ext == "rb":
        return _slice_ruby(text, allowed, class_name)
    return _slice_api_comments(text, allowed)


def merge_unlocked_methods(
    work: str, full: str, ext: str, allowed: set[str], class_name: str
) -> str:
    missing = [name for name in sorted(allowed) if not _declares(work, ext, name)]
    if ext == "java":
        extras = "".join(_java_method(full, name) or "" for name in missing)
        if extras:
            work = _ensure_java_imports(
                _insert_before_java_class_close(work, extras, class_name), full, extras
            )
        return _inject_java_docs(work, full, allowed)
    if ext == "py":
        extras = "".join(_python_method(full, name) or "" for name in missing)
        if extras:
            work = _insert_before_python_class_end(work, extras, class_name)
        return _inject_python_docs(work, full, allowed)
    if ext in {"js", "ts"}:
        extras = "".join(_js_method(full, name) or "" for name in missing)
        if extras:
            return _insert_before_js_class_close(work, extras, class_name)
        return work
    if ext == "rb":
        extras = "".join(_ruby_method(full, name) or "" for name in missing)
        if extras:
            return _insert_before_ruby_class_end(work, extras, class_name)
        return work
    return _merge_api_comments(work, full, allowed)


def class_name_for(problem: str) -> str:
    return _CLASS[problem]


_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_PY_DOCSTRING = re.compile(r'("""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\')')


def _drop_unclosed(text: str, opener: str) -> str:
    idx = text.find(opener)
    if idx >= 0:
        return text[:idx]
    return text


def _code_lines(text: str, ext: str) -> list[str]:
    if ext in {"js", "ts", "java"}:
        text = _BLOCK_COMMENT.sub("\n", text)
        text = _drop_unclosed(text, "/*")
    if ext == "py":
        text = _PY_DOCSTRING.sub("\n", text)
        text = _drop_unclosed(text, '"""')
        text = _drop_unclosed(text, "'''")
    return [
        line.strip()
        for line in text.splitlines()
        if line.strip() and not line.strip().startswith(("#", "//"))
    ]


def declares_class(text: str, ext: str, class_name: str) -> bool:
    """True when work declares the class, not just mentions its name."""
    token = re.escape(class_name)
    lines = _code_lines(text, ext)
    decl = re.compile(rf"^(?:(?:export(?:\s+default)?|public)\s+)?class\s+{token}\b")
    if ext == "py":
        return any(decl.match(line) for line in lines)
    if ext == "java":
        return any(decl.match(line) for line in lines)
    if ext in {"js", "ts"}:
        assign = re.compile(rf"^(?:const|let|var)\s+{token}\s*=\s*class\b")
        shorthand = re.compile(rf"^{token}\s*:\s*class\b")
        fn = re.compile(rf"^(?:export\s+)?function\s+{token}\b")
        return any(
            decl.match(line) or assign.match(line) or shorthand.match(line) or fn.match(line)
            for line in lines
        )
    if ext == "rb":
        return any(decl.match(line) for line in lines)
    return class_name in text


def naming_for(lang_id: str) -> str:
    return str(language(lang_id)["naming"])


def _js_declares_line(line: str, name: str) -> bool:
    stripped = line.strip()
    if stripped.endswith(";"):
        return False
    body = stripped
    if body.startswith("async "):
        body = body[len("async ") :].lstrip()
    if not body.startswith(f"{name}("):
        return False
    return "{" in body


def _java_declares_name(text: str, pos: int, name: str) -> bool:
    pub = text.rfind("public ", 0, pos)
    if pub < 0:
        return False
    sig = text[pub + len("public ") : pos + len(name)]
    if "{" in sig:
        return False
    tokens = sig.split()
    return bool(tokens) and tokens[-1] == name


def _declares(text: str, ext: str, name: str) -> bool:
    lines = _code_lines(text, ext)
    if ext == "java":
        needle = f"{name}("
        for line in lines:
            idx = 0
            while True:
                pos = line.find(needle, idx)
                if pos < 0:
                    break
                if pos > 0 and (line[pos - 1].isalnum() or line[pos - 1] == "_"):
                    idx = pos + 1
                    continue
                if _java_declares_name(line, pos, name):
                    return True
                idx = pos + 1
        return False
    if ext in {"js", "ts"}:
        return any(_js_declares_line(line, name) for line in lines)
    if ext == "py":
        return any(f"def {name}(" in line for line in lines)
    if ext == "rb":
        return any(f"def {name}(" in line or f"def {name} " in line for line in lines)
    return any(token in line for line in lines for token in _name_forms(name))


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
        if not _java_declares_name(text, pos, name):
            idx = pos + 1
            continue
        pub = text.rfind("public ", 0, pos)
        return _include_java_doc(text, pub)


def _include_java_doc(text: str, pub: int) -> int:
    close = text.rfind("*/", 0, pub)
    if close < 0 or text[close + 2 : pub].strip() != "":
        return pub
    open_pos = text.rfind("/**", 0, close)
    if open_pos < 0:
        return pub
    return text.rfind("\n", 0, open_pos) + 1


def _skip_quoted(text: str, start: int, quote: str) -> int:
    i = start + 1
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "\\":
            i += 2
            continue
        if ch == quote:
            return i + 1
        i += 1
    return n


def _brace_close(text: str, brace: int) -> int:
    """Index of the matching `}`, skipping comments and quoted braces."""
    depth = 0
    i = brace
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "/" and i + 1 < n:
            nxt = text[i + 1]
            if nxt == "/":
                nl = text.find("\n", i + 2)
                i = n if nl < 0 else nl + 1
                continue
            if nxt == "*":
                end = text.find("*/", i + 2)
                i = n if end < 0 else end + 2
                continue
        if ch == '"':
            i = _skip_quoted(text, i, '"')
            continue
        if ch == "'":
            i = _skip_quoted(text, i, "'")
            continue
        if ch == "`":
            i = _skip_quoted(text, i, "`")
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unbalanced braces")


def _brace_block(text: str, start: int) -> str:
    brace = text.find("{", start)
    close = _brace_close(text, brace)
    end = close + 1
    if end < len(text) and text[end] == "\n":
        end += 1
    return text[start:end]


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


def _insert_before_java_class_close(text: str, extra: str, class_name: str) -> str:
    if not extra:
        return text
    close = _js_class_close(text, class_name)
    prefix = text[:close].rstrip() + "\n\n"
    return prefix + extra.lstrip("\n") + text[close:]


def _insert_before_python_class_end(work: str, extra: str, class_name: str) -> str:
    if not extra:
        return work
    match = re.search(rf"^class {re.escape(class_name)}\b", work, re.MULTILINE)
    if match is None:
        raise ValueError(f"missing class {class_name}")
    nxt = re.search(r"^class ", work[match.end() :], re.MULTILINE)
    extras = extra.lstrip("\n")
    if nxt is None:
        return work.rstrip() + "\n\n" + extras
    at = match.end() + nxt.start()
    return work[:at].rstrip() + "\n\n" + extras + "\n\n" + work[at:]


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


def _inject_java_docs(work: str, full: str, allowed: set[str]) -> str:
    edits: list[tuple[int, int, str]] = []
    for name in allowed:
        start = _java_method_start(work, name)
        if start is None:
            continue
        pub = work.find("public ", start)
        if pub < 0:
            continue
        stub_start = _java_method_start(full, name)
        if stub_start is None:
            continue
        stub_pub = full.find("public ", stub_start)
        if stub_pub < 0 or stub_start >= stub_pub:
            continue
        doc = full[stub_start:stub_pub]
        if "/**" not in doc:
            continue
        if start < pub:
            if "Move drop onto keep" not in work[start:pub]:
                continue
            edits.append((start, pub, doc))
            continue
        edits.append((pub, pub, doc))
    for begin, end, doc in sorted(edits, reverse=True):
        work = work[:begin] + doc + work[end:]
    return work


def _python_has_doc(block: str) -> bool:
    lines = block.splitlines()
    i = 0
    while i < len(lines) and not lines[i].lstrip().startswith("def "):
        i += 1
    while i < len(lines) and not lines[i].rstrip().endswith(":"):
        i += 1
    i += 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines):
        return False
    stripped = lines[i].lstrip()
    return stripped.startswith('"""') or stripped.startswith("'''")


def _python_doc_lines(full: str, name: str) -> str | None:
    block = _python_method(full, name)
    if block is None:
        return None
    lines = block.splitlines()
    i = 0
    while i < len(lines) and not lines[i].lstrip().startswith("def "):
        i += 1
    while i < len(lines) and not lines[i].rstrip().endswith(":"):
        i += 1
    i += 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines):
        return None
    stripped = lines[i].lstrip()
    if not (stripped.startswith('"""') or stripped.startswith("'''")):
        return None
    quote = stripped[:3]
    start = i
    if stripped.count(quote) >= 2 and len(stripped) > 3:
        return lines[i]
    i += 1
    while i < len(lines):
        if quote in lines[i]:
            return "\n".join(lines[start : i + 1])
        i += 1
    return None


def _inject_python_docs(work: str, full: str, allowed: set[str]) -> str:
    for name in allowed:
        block = _python_method(work, name)
        if block is None or "Move drop onto keep" not in block:
            continue
        old_doc = _python_doc_lines(work, name)
        new_doc = _python_doc_lines(full, name)
        if old_doc and new_doc and old_doc != new_doc:
            work = work.replace(old_doc, new_doc, 1)
    lines = work.splitlines(keepends=True)
    inserts: list[tuple[int, list[str]]] = []
    i = 0
    while i < len(lines):
        stripped = lines[i].lstrip()
        if stripped.startswith("def "):
            name = stripped[4:].split("(")[0]
            if name in allowed:
                block = _python_method(work, name)
                if block is not None and not _python_has_doc(block):
                    doc = _python_doc_lines(full, name)
                    if doc:
                        j = i
                        while j < len(lines) and not lines[j].rstrip().endswith(":"):
                            j += 1
                        inserts.append((j + 1, [ln + "\n" for ln in doc.splitlines()]))
        i += 1
    for idx, chunk in sorted(inserts, reverse=True):
        lines[idx:idx] = chunk
    return "".join(lines)


def _slice_js(text: str, allowed: set[str], class_name: str) -> str:
    ctor = _js_method(text, "constructor") or "  constructor() {}\n"
    methods = []
    for name in _js_method_order(text):
        if name == "constructor" or name not in allowed:
            continue
        block = _js_method(text, name)
        if block:
            methods.append(block)
    body = ctor if ctor.endswith("\n") else ctor + "\n"
    for block in methods:
        body += block if block.endswith("\n") else block + "\n"
    return _js_header(text, class_name) + body + _js_footer(text)


def _js_header(text: str, class_name: str) -> str:
    marker = f"class {class_name}"
    idx = text.find(marker)
    if idx < 0:
        raise ValueError(f"missing {marker}")
    brace = text.find("{", idx)
    return text[: brace + 1] + "\n"


def _js_footer(text: str) -> str:
    for needle in ("module.exports", "export "):
        idx = text.find(needle)
        if idx >= 0:
            tail = text[idx:]
            if not tail.endswith("\n"):
                tail += "\n"
            return "}\n" + tail
    return "}\n"


def _js_method_order(text: str) -> list[str]:
    names: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if "(" not in stripped:
            continue
        if stripped.startswith(("class ", "module.exports", "export ")):
            continue
        name = stripped.split("(")[0].strip()
        if name.isidentifier():
            names.append(name)
    return names


def _js_method_start(text: str, name: str) -> int | None:
    idx = 0
    needle = f"{name}("
    while True:
        pos = text.find(needle, idx)
        if pos < 0:
            return None
        if pos > 0 and (text[pos - 1].isalnum() or text[pos - 1] in "._"):
            idx = pos + 1
            continue
        return text.rfind("\n", 0, pos) + 1


def _js_method(text: str, name: str) -> str | None:
    start = _js_method_start(text, name)
    if start is None:
        return None
    return _brace_block(text, start)


def _insert_before_js_class_close(text: str, extra: str, class_name: str) -> str:
    if not extra:
        return text
    close = _js_class_close(text, class_name)
    prefix = text[:close].rstrip() + "\n"
    return prefix + extra.lstrip("\n") + text[close:]


def _js_class_close(text: str, class_name: str) -> int:
    markers = (
        f"public class {class_name}",
        f"class {class_name}",
        f"{class_name} = class",
        f"{class_name}: class",
    )
    idx = -1
    for marker in markers:
        idx = text.find(marker)
        if idx >= 0:
            break
    if idx < 0:
        raise ValueError(f"missing class {class_name}")
    brace = text.find("{", idx)
    return _brace_close(text, brace)


def _name_forms(name: str) -> set[str]:
    forms = {name}
    if "_" in name:
        parts = name.split("_")
        forms.add(parts[0] + "".join(part.title() for part in parts[1:]))
        return forms
    snake: list[str] = []
    for i, ch in enumerate(name):
        if ch.isupper() and i:
            snake.append("_")
        snake.append(ch.lower())
    forms.add("".join(snake))
    return forms


def _allowed_forms(allowed: set[str]) -> set[str]:
    forms: set[str] = set()
    for name in allowed:
        forms.update(_name_forms(name))
    return forms


def _api_ident(line: str) -> str | None:
    match = _API_IDENT.search(line)
    if match is None:
        return None
    return match.group(1)


def _is_comment_line(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return False
    if stripped.startswith(("//", "#", "--", ";;", "%", "!")):
        return True
    if stripped.startswith('"') and stripped.endswith('"'):
        return True
    if stripped.startswith("(*") or stripped.endswith("*)"):
        return True
    return False


def _slice_api_comments(text: str, allowed: set[str]) -> str:
    allowed_all = _allowed_forms(allowed)
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    in_block = False
    for line in lines:
        stripped = line.strip()
        if "(*" in stripped:
            in_block = True
        consider = _is_comment_line(stripped) or (in_block and "(*" not in stripped)
        name = _api_ident(stripped) if consider else None
        if name is not None and name not in allowed_all:
            if "*)" in stripped and "(*" not in stripped:
                out.append("*)\n")
            if "*)" in stripped:
                in_block = False
            continue
        out.append(line)
        if "*)" in stripped:
            in_block = False
    return "".join(out)


def _merge_api_comments(work: str, full: str, allowed: set[str]) -> str:
    allowed_all = _allowed_forms(allowed)
    extras: list[str] = []
    in_block = False
    for line in full.splitlines(keepends=True):
        stripped = line.strip()
        if "(*" in stripped:
            in_block = True
        consider = _is_comment_line(stripped) or (in_block and "(*" not in stripped)
        name = _api_ident(stripped) if consider else None
        present = name is not None and any(form in work for form in _name_forms(name))
        if name is not None and name in allowed_all and not present:
            extras.append(line if line.endswith("\n") else line + "\n")
        if "*)" in stripped:
            in_block = False
    if not extras:
        return work
    return _insert_api_comment_lines(work, extras)


def _insert_api_comment_lines(work: str, extras: list[str]) -> str:
    lines = work.splitlines(keepends=True)
    last = -1
    in_block = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if "(*" in stripped:
            in_block = True
        if _is_comment_line(stripped) or in_block:
            last = i
        elif stripped:
            break
        if "*)" in stripped:
            in_block = False
    if last < 0:
        return "".join(extras) + work
    closer = lines[last]
    if "*)" in closer.strip() and "(*" not in closer.strip():
        lines[last:last] = extras
        return "".join(lines)
    lines[last + 1 : last + 1] = extras
    return "".join(lines)


def _slice_ruby(text: str, allowed: set[str], class_name: str) -> str:
    header = _ruby_header(text, class_name)
    init = _ruby_method(text, "initialize") or ""
    parts = [header.rstrip(), init.rstrip()]
    for name in _ruby_method_order(text):
        if name == "initialize" or name not in allowed:
            continue
        block = _ruby_method(text, name)
        if block:
            parts.append(block.rstrip())
    body = "\n".join(part for part in parts if part)
    if not body.endswith("\n"):
        body += "\n"
    return body + "end\n"


def _ruby_header(text: str, class_name: str) -> str:
    marker = f"class {class_name}"
    for line in text.splitlines(keepends=True):
        if line.strip().startswith(marker):
            return line if line.endswith("\n") else line + "\n"
    raise ValueError(f"missing {marker}")


def _ruby_method_order(text: str) -> list[str]:
    names: list[str] = []
    for line in text.splitlines():
        match = _RUBY_DEF.match(line)
        if match:
            names.append(match.group(2))
    return names


def _ruby_method(text: str, name: str) -> str | None:
    lines = text.splitlines(keepends=True)
    start = None
    for i, line in enumerate(lines):
        match = _RUBY_DEF.match(line)
        if match and match.group(2) == name:
            start = i
            break
    if start is None:
        return None
    depth = 0
    for j in range(start, len(lines)):
        stripped = lines[j].strip()
        if stripped.startswith("def "):
            depth += 1
        if stripped == "end" or stripped.startswith("end ") or stripped.startswith("end;"):
            depth -= 1
            if depth == 0:
                return "".join(lines[start : j + 1])
    return "".join(lines[start:])


def _insert_before_ruby_class_end(work: str, extra: str, class_name: str) -> str:
    if not extra:
        return work
    match = re.search(rf"^(\s*)class {re.escape(class_name)}\b", work, re.MULTILINE)
    if match is None:
        raise ValueError(f"missing class {class_name}")
    indent = match.group(1)
    closer = re.search(rf"^{re.escape(indent)}end\b", work[match.end() :], re.MULTILINE)
    if closer is None:
        raise ValueError(f"unbalanced end for class {class_name}")
    close = match.end() + closer.start()
    prefix = work[:close].rstrip() + "\n"
    return prefix + extra.lstrip("\n") + work[close:]
