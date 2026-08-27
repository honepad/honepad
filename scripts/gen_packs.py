#!/usr/bin/env python3
"""Generate langs/catalog.json and per-language stubs."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Official CodeSignal lists (support article 2026-04-15 + assessments page).
GCA = [
    ("clojure", "Clojure", "clj", "snake"),
    ("coffeescript", "CoffeeScript", "coffee", "camel"),
    ("common-lisp", "Common Lisp", "lisp", "snake"),
    ("c", "C", "c", "snake"),
    ("cpp", "C++", "cpp", "camel"),
    ("csharp", "C#", "cs", "camel"),
    ("d", "D", "d", "camel"),
    ("dart", "Dart", "dart", "camel"),
    ("elixir", "Elixir", "ex", "snake"),
    ("erlang", "Erlang", "erl", "snake"),
    ("freepascal", "Free Pascal", "pas", "camel"),
    ("fortran", "Fortran", "f90", "snake"),
    ("fsharp", "F#", "fs", "camel"),
    ("go", "Go", "go", "camel"),
    ("groovy", "Groovy", "groovy", "camel"),
    ("haskell", "Haskell", "hs", "camel"),
    ("java", "Java", "java", "camel"),
    ("javascript", "JavaScript", "js", "camel"),
    ("julia", "Julia", "jl", "snake"),
    ("kotlin", "Kotlin", "kt", "camel"),
    ("lua", "Lua", "lua", "snake"),
    ("nim", "Nim", "nim", "camel"),
    ("objc", "Objective-C", "m", "camel"),
    ("ocaml", "OCaml", "ml", "snake"),
    ("octave", "GNU Octave", "m", "snake"),
    ("perl", "Perl", "pl", "snake"),
    ("php", "PHP", "php", "camel"),
    ("python2", "Python 2", "py", "snake"),
    ("python3", "Python 3", "py", "snake"),
    ("r", "R", "R", "snake"),
    ("ruby", "Ruby", "rb", "snake"),
    ("rust", "Rust", "rs", "snake"),
    ("scala", "Scala", "scala", "camel"),
    ("smalltalk", "Smalltalk", "st", "camel"),
    ("swift", "Swift", "swift", "camel"),
    ("tcl", "Tcl", "tcl", "snake"),
    ("typescript", "TypeScript", "ts", "camel"),
    ("vb", "Visual Basic", "vb", "camel"),
]

ICA = {
    "csharp",
    "cpp",
    "go",
    "java",
    "javascript",
    "kotlin",
    "php",
    "python3",
    "ruby",
    "rust",
    "swift",
    "typescript",
}

FE = [
    ("angular-ts", "Angular (TypeScript)", "ts", "camel"),
    ("react-js", "React (JavaScript)", "jsx", "camel"),
    ("react-ts", "React (TypeScript)", "tsx", "camel"),
    ("vue-js", "Vue (JavaScript)", "js", "camel"),
    ("vue-ts", "Vue (TypeScript)", "ts", "camel"),
]

SQL = [
    ("mysql", "MySQL", "sql", "snake"),
    ("postgresql", "PostgreSQL", "sql", "snake"),
    ("mssql", "Microsoft SQL", "sql", "snake"),
]

EXTRA = [
    ("hack", "Hack", "hack", "camel"),
    ("mongodb", "MongoDB", "js", "camel"),
    ("bash", "Bash", "sh", "snake"),
    ("powershell", "PowerShell", "ps1", "camel"),
    ("shell", "Shell", "sh", "snake"),
]

ADAPTERS = {
    "python3": "python-import",
    "javascript": "node",
    "go": "go-run",
    "rust": "cargo-run",
    "ruby": "ruby",
    "php": "php",
    "typescript": "node",
    "java": "javac",
    "csharp": "dotnet",
    "kotlin": "kotlinc",
    "cpp": "g++",
    "swift": "swiftc",
}

CI = {
    "python3",
    "javascript",
    "go",
    "java",
    "ruby",
    "php",
    "perl",
    "lua",
    "typescript",
    "rust",
    "cpp",
    "c",
    "csharp",
    "kotlin",
    "swift",
}

BANK_METHODS = [
    "create_account(timestamp, account_id)",
    "deposit(timestamp, account_id, amount)",
    "transfer(timestamp, source_account_id, target_account_id, amount)",
    "top_spenders(timestamp, n)",
    "pay(timestamp, account_id, amount)",
    "get_payment_status(timestamp, account_id, payment)",
    "merge_accounts(timestamp, account_id_1, account_id_2)",
    "get_balance(timestamp, account_id, time_at)",
]

DB_METHODS = [
    "set(key, field, value)",
    "get(key, field)",
    "delete(key, field)",
    "scan(key)",
    "scan_by_prefix(key, prefix)",
    "set_at(key, field, value, timestamp)",
    "set_at_with_ttl(key, field, value, timestamp, ttl)",
    "delete_at(key, field, timestamp)",
    "get_at(key, field, timestamp)",
    "scan_at(key, timestamp)",
    "scan_by_prefix_at(key, prefix, timestamp)",
    "backup(timestamp)",
    "restore(timestamp, timestamp_to_restore)",
]

FILE_METHODS = [
    "add_file(name, size)",
    "get_file_size(name)",
    "delete_file(name)",
    "get_n_largest(prefix, n)",
    "add_user(user_id, capacity)",
    "add_file_by(user_id, name, size)",
    "merge_user(user_id1, user_id2)",
    "backup_user(user_id)",
    "restore_user(user_id)",
]

WORKER_METHODS = [
    "add_worker(worker_id, position, compensation)",
    "register(worker_id, timestamp)",
    "get(worker_id)",
    "top_n_workers(n, position)",
    "promote(worker_id, new_position, new_compensation, start_timestamp)",
    "calc_salary(worker_id, start_timestamp, end_timestamp)",
]


def suites_for(lang_id: str, extra_suite: str | None) -> list[str]:
    out = []
    if extra_suite:
        out.append(extra_suite)
    if lang_id in {x[0] for x in GCA}:
        out.append("gca")
    if lang_id in ICA:
        out.append("ica")
    if lang_id in {"python2", "python3"}:
        out.append("ml")
    return out or [extra_suite or "gca"]


def python_stub(class_name: str, methods: list[str]) -> str:
    lines = [f"class {class_name}:", "    def __init__(self):", "        pass", ""]
    for sig in methods:
        name = sig.split("(")[0]
        args = sig[sig.index("(") :]
        inner = args[1:-1]
        self_args = f"(self, {inner})" if inner else "(self)"
        lines.append(f"    def {name}{self_args}:")
        lines.append("        raise NotImplementedError")
        lines.append("")
    return "\n".join(lines)


def comment_stub(ext: str, class_name: str, methods: list[str]) -> str:
    if ext in {"js", "ts", "jsx", "tsx"}:
        body = [f"class {class_name} {{", "  constructor() {}"]
        for sig in methods:
            name = sig.split("(")[0]
            # camel
            parts = name.split("_")
            camel = parts[0] + "".join(p.title() for p in parts[1:])
            args = sig[sig.index("(") + 1 : -1]
            body.append(f"  {camel}({args}) {{ throw new Error('not implemented'); }}")
        body.append("}")
        body.append(f"module.exports = {{ {class_name} }};")
        return "\n".join(body) + "\n"
    if ext == "go":
        return (
            "package main\n\n"
            f"type {class_name} struct {{}}\n\n"
            f"func New{class_name}() *{class_name} {{ return &{class_name}{{}} }}\n"
        )
    if ext == "rs":
        return f"pub struct {class_name};\n\nimpl {class_name} {{\n    pub fn new() -> Self {{ Self }}\n}}\n"
    if ext == "java":
        return f"public class {class_name} {{\n    public {class_name}() {{}}\n}}\n"
    if ext == "rb":
        lines = [f"class {class_name}", "  def initialize", "  end"]
        for sig in methods:
            name = sig.split("(")[0]
            args = sig[sig.index("(") + 1 : -1].replace(", ", ", ")
            lines.append(f"  def {name}({args})")
            lines.append("    raise 'not implemented'")
            lines.append("  end")
        lines.append("end")
        return "\n".join(lines) + "\n"
    if ext == "php":
        return f"<?php\nclass {class_name} {{\n}}\n"
    comment = {
        "c": "//",
        "cpp": "//",
        "cs": "//",
        "kt": "//",
        "swift": "//",
        "scala": "//",
        "groovy": "//",
        "d": "//",
        "dart": "//",
        "fs": "//",
        "m": "//",
        "sql": "--",
        "sh": "#",
        "ps1": "#",
        "py": "#",
        "pl": "#",
        "lua": "--",
        "r": "#",
        "jl": "#",
        "ex": "#",
        "erl": "%",
        "hs": "--",
        "lisp": ";;",
        "clj": ";;",
        "coffee": "#",
        "nim": "#",
        "ml": "(*",
        "pas": "{",
        "f90": "!",
        "tcl": "#",
        "vb": "'",
        "st": "\"",
        "hack": "//",
    }.get(ext, "#")
    header = f"{comment} {class_name} stub. Fill methods from the problem spec.\n"
    return header + "\n".join(f"{comment} {m}" for m in methods) + "\n"


def main() -> None:
    rows = []
    seen = set()

    def add(lang_id, name, ext, naming, extra=None):
        if lang_id in seen:
            return
        seen.add(lang_id)
        suites = []
        if extra:
            suites.append(extra)
        if lang_id in {x[0] for x in GCA}:
            suites.append("gca")
        if lang_id in ICA:
            suites.append("ica")
        if lang_id in {"python2", "python3"}:
            suites.append("ml")
        rows.append(
            {
                "id": lang_id,
                "name": name,
                "ext": ext,
                "naming": naming,
                "suites": suites,
                "ci": lang_id in CI,
                "adapter": ADAPTERS.get(lang_id, "stub"),
            }
        )

    for item in GCA:
        add(*item)
    for item in FE:
        add(*item, extra="frontend")
    for item in SQL:
        add(*item, extra="sql")
    for item in EXTRA:
        add(*item, extra="extra")

    catalog = {
        "problems": [
            "bank_system",
            "in_memory_database",
            "file_storage",
            "workers",
        ],
        "required_ids": [r["id"] for r in rows],
        "languages": rows,
    }
    dest = ROOT / "langs" / "catalog.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")

    for row in rows:
        lang_dir = ROOT / "langs" / row["id"]
        for problem, cls, methods in (
            ("bank_system", "Simulation", BANK_METHODS),
            ("in_memory_database", "InMemoryDatabase", DB_METHODS),
            ("file_storage", "Simulation", FILE_METHODS),
            ("workers", "Simulation", WORKER_METHODS),
        ):
            pack = lang_dir / "problems" / problem
            pack.mkdir(parents=True, exist_ok=True)
            stub = pack / f"stub.{row['ext']}"
            if row["id"] == "python3":
                stub.write_text(python_stub(cls, methods), encoding="utf-8")
            else:
                stub.write_text(comment_stub(row["ext"], cls, methods), encoding="utf-8")
        meta = lang_dir / "meta.json"
        meta.write_text(json.dumps(row, indent=2) + "\n", encoding="utf-8")

    print(f"wrote {len(rows)} languages")


if __name__ == "__main__":
    main()
