"""VS Code workspace: work file plus unlocked public traces."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from honepad.catalog import language, repo_root
from honepad.session import session_path, work_src
from honepad.term import file_link, file_uri
from honepad.traces import load_cases, problem_dir
from honepad.workstub import class_name_for


def workspace_dir(problem: str, lang: str) -> Path:
    return session_path().parent / "workspace" / f"{problem}-{lang}"


def workspace_file(problem: str, lang: str) -> Path:
    return workspace_dir(problem, lang) / "honepad.code-workspace"


def write_workspace(problem: str, lang: str, unlocked: int) -> Path:
    root = workspace_dir(problem, lang)
    public = root / "public"
    public.mkdir(parents=True, exist_ok=True)
    work = work_src(problem, lang)
    cases = load_cases(problem, unlocked)
    (public / "cases.json").write_text(json.dumps(cases, indent=2) + "\n", encoding="utf-8")
    spec_dir = problem_dir(problem) / "spec"
    latest = spec_dir / f"level{unlocked}.md"
    if latest.is_file():
        (public / "spec.md").write_text(latest.read_text(encoding="utf-8"), encoding="utf-8")
    for level in range(1, unlocked + 1):
        src = spec_dir / f"level{level}.md"
        if src.is_file():
            dest = public / f"level{level}.md"
            dest.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    row = language(lang)
    if row["id"] == "java":
        _write_java_public(public, work, problem)
    _write_readme(public, problem, lang, unlocked, work)
    _write_tasks(public, problem, lang)
    payload = {
        "folders": [
            {"name": "work", "path": str(work.parent.resolve())},
            {"name": "public-tests", "path": str(public.resolve())},
        ],
        "settings": {"files.exclude": {"**/.DS_Store": True}},
    }
    dest = workspace_file(problem, lang)
    dest.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return dest


def open_vscode(path: Path) -> int:
    cmd = _code_cmd()
    if cmd is None:
        print("FAIL: vscode 'code' not on PATH")
        print(f"WORKSPACE: {file_link(path)}")
        return 1
    subprocess.Popen([*cmd, "--new-window", str(path)])
    print(f"OK: {file_link(path)}")
    return 0


def _code_cmd() -> list[str] | None:
    for name in ("code", "code-insiders"):
        found = shutil.which(name)
        if found:
            return [found]
    return None


def _link_or_copy(src: Path, dest: Path) -> None:
    if dest.exists() or dest.is_symlink():
        dest.unlink()
    try:
        dest.symlink_to(src.resolve())
    except OSError:
        dest.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")


def _write_java_public(public: Path, work: Path, problem: str) -> None:
    pack = repo_root() / "langs" / "java"
    shutil.copy(pack / "Adapter.java", public / "Adapter.java")
    shutil.copy(pack / "MiniJson.java", public / "MiniJson.java")
    class_name = class_name_for(problem)
    if work.is_file():
        _link_or_copy(work, public / f"{class_name}.java")
    script = public / "run-public.sh"
    script.write_text(
        "\n".join(
            [
                "#!/bin/sh",
                "set -e",
                'cd "$(dirname "$0")"',
                f"javac Adapter.java MiniJson.java {class_name}.java",
                f"java Adapter cases.json {class_name}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    script.chmod(0o755)


def _write_readme(public: Path, problem: str, lang: str, unlocked: int, work: Path) -> None:
    lines = [
        f"# {problem} public tests (unlocked through L{unlocked})",
        "",
        "These are the public traces honepad runs. Hidden tests are not here.",
        "",
        f"Work file: {work}",
        f"URI: {file_uri(work)}",
        "",
        "VS Code: Terminal > Run Task > Run public tests, or",
        f"`{sys.executable} -m honepad run {problem} --lang {lang}`.",
        "",
    ]
    if lang == "java":
        lines.append("Java without honepad: `./run-public.sh` (Adapter + cases.json).")
        lines.append("")
    (public / "README.md").write_text("\n".join(lines), encoding="utf-8")


def _write_tasks(public: Path, problem: str, lang: str) -> None:
    vscode = public / ".vscode"
    vscode.mkdir(exist_ok=True)
    tasks: list[dict[str, object]] = [
        {
            "label": "Run public tests",
            "type": "shell",
            "command": sys.executable,
            "args": ["-m", "honepad", "run", problem, "--lang", lang],
            "group": {"kind": "test", "isDefault": True},
            "presentation": {"reveal": "always", "panel": "shared"},
            "problemMatcher": [],
        }
    ]
    if lang == "java":
        tasks.append(
            {
                "label": "Run public tests (javac)",
                "type": "shell",
                "command": "${workspaceFolder}/run-public.sh",
                "group": "test",
                "options": {"cwd": "${workspaceFolder}"},
                "problemMatcher": [],
            }
        )
    (vscode / "tasks.json").write_text(
        json.dumps({"version": "2.0.0", "tasks": tasks}, indent=2) + "\n",
        encoding="utf-8",
    )
