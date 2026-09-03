"""VS Code workspace: work file plus unlocked public traces."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from honepad.catalog import language, repo_root
from honepad.javatest import render_junit, render_pom
from honepad.pythontest import render_pytest
from honepad.session import (
    _ensure_real_session_dir,
    _replace_text,
    _require_real_session_dir,
    max_level,
    session_path,
    work_src,
)
from honepad.term import file_link, file_uri
from honepad.traces import load_cases, problem_dir
from honepad.workstub import class_name_for


def workspace_dir(problem: str, lang: str) -> Path:
    return session_path().parent / "workspace" / f"{problem}-{lang}"


def workspace_file(problem: str, lang: str) -> Path:
    return workspace_dir(problem, lang) / "honepad.code-workspace"


def public_test_file(problem: str, lang: str) -> Path | None:
    ident = language(lang)["id"]
    public = workspace_dir(problem, lang) / "public"
    if ident == "java":
        return public / "src" / "test" / "java" / "PublicTracesTest.java"
    if ident == "python3":
        return public / "test_public.py"
    return None


def refresh_workspace(problem: str, lang: str, unlocked: int, cleared: bool = False) -> Path | None:
    root = workspace_dir(problem, lang)
    if not root.is_dir():
        return None
    cases = load_cases(problem, unlocked)
    dest = root / "public" / "cases.json"
    if dest.is_file():
        try:
            existing = json.loads(dest.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            existing = None
        if existing == cases:
            return workspace_file(problem, lang)
    return write_workspace(problem, lang, unlocked, cleared=cleared)


def write_workspace(problem: str, lang: str, unlocked: int, cleared: bool = False) -> Path:
    root = workspace_dir(problem, lang)
    work = work_src(problem, lang)
    row = language(lang)
    if row["id"] in {"java", "python3"} and not work.is_file():
        raise ValueError(f"work file missing: {work}")
    public = root / "public"
    _ensure_real_session_dir(root, "workspace")
    _ensure_real_session_dir(public, "public")
    _require_real_session_dir(work.parent, "work")
    cases = load_cases(problem, unlocked)
    _replace_text(public / "cases.json", json.dumps(cases, indent=2) + "\n")
    spec_folder = _write_specs(public, problem, unlocked)
    if row["id"] == "java":
        _write_java_public(public, work, problem, cases, unlocked)
        _write_work_java_settings(work.parent)
    elif row["id"] == "python3":
        _write_python_public(public, work, problem, cases)
    _write_readme(public, problem, lang, unlocked, work, cleared=cleared)
    _write_tasks(public, problem, lang, unlocked, cleared=cleared)
    folders = [
        {"name": "spec", "path": str(spec_folder.resolve())},
        {"name": "public-tests", "path": str(public.resolve())},
        {"name": "work", "path": str(work.parent.resolve())},
    ]
    payload = {
        "folders": folders,
        "settings": _workspace_settings(row["id"]),
        "extensions": {"recommendations": _recommended_extensions(row["id"])},
    }
    dest = workspace_file(problem, lang)
    _replace_text(dest, json.dumps(payload, indent=2) + "\n")
    return dest


def open_vscode(path: Path) -> int:
    cmd = _code_cmd()
    if cmd is None:
        print("FAIL: vscode 'code' not on PATH")
        print("NOTE: macOS Command Palette \"Shell Command: Install 'code' command in PATH\"")
        print(f"WORKSPACE: {file_link(path)}")
        return 1
    subprocess.Popen(
        [*cmd, "--new-window", str(path)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
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


def _recommended_extensions(lang: str) -> list[str]:
    if lang == "java":
        return ["vscjava.vscode-java-pack"]
    if lang == "python3":
        return ["ms-python.python"]
    return []


def _workspace_settings(lang: str) -> dict[str, object]:
    settings: dict[str, object] = {"files.exclude": {"**/.DS_Store": True}}
    if lang == "java":
        settings["java.configuration.updateBuildConfiguration"] = "automatic"
        settings["java.import.maven.enabled"] = True
        settings["java.project.explorer.showNonJavaResources"] = True
        # work/ is a multi-root folder and is also linked under public/src.
        # Exclude it so JDT does not import two Simulation copies.
        settings["java.import.exclusions"] = [
            "**/node_modules/**",
            "**/.metadata/**",
            "**/archetype-resources/**",
            "**/META-INF/maven/**",
            "**/work/**",
        ]
    return settings


def _write_work_java_settings(work_dir: Path) -> None:
    vscode = work_dir / ".vscode"
    _ensure_real_session_dir(vscode, "vscode")
    _replace_text(
        vscode / "settings.json",
        json.dumps(
            {
                "java.import.maven.enabled": False,
                "java.import.gradle.enabled": False,
            },
            indent=2,
        )
        + "\n",
    )


def _write_extensions(public: Path, ids: list[str]) -> None:
    vscode = public / ".vscode"
    _ensure_real_session_dir(vscode, "vscode")
    _replace_text(
        vscode / "extensions.json",
        json.dumps({"recommendations": ids}, indent=2) + "\n",
    )


def _write_java_public(
    public: Path,
    work: Path,
    problem: str,
    cases: list[dict[str, object]],
    unlocked: int,
) -> None:
    if not work.is_file():
        raise ValueError(f"work file missing: {work}")
    pack = repo_root() / "langs" / "java"
    _replace_text(public / "Adapter.java", (pack / "Adapter.java").read_text(encoding="utf-8"))
    _replace_text(public / "MiniJson.java", (pack / "MiniJson.java").read_text(encoding="utf-8"))
    main_java = public / "src" / "main" / "java"
    test_java = public / "src" / "test" / "java"
    _ensure_real_session_dir(main_java, "src")
    _ensure_real_session_dir(test_java, "src")
    class_name = class_name_for(problem)
    _link_or_copy(work, main_java / f"{class_name}.java")
    spec = problem_dir(problem) / "spec" / f"level{unlocked}.md"
    if spec.is_file():
        _replace_text(main_java / "spec.md", spec.read_text(encoding="utf-8"))
    _replace_text(test_java / "PublicTracesTest.java", render_junit(problem, cases))
    _replace_text(public / "pom.xml", render_pom(problem, "java"))
    _write_extensions(public, ["vscjava.vscode-java-pack"])
    script = public / "run-public.sh"
    _replace_text(
        script,
        "\n".join(
            [
                "#!/bin/sh",
                "set -e",
                'cd "$(dirname "$0")"',
                "if command -v mvn >/dev/null 2>&1; then",
                "  mvn -q test",
                "  exit $?",
                "fi",
                f"cp src/main/java/{class_name}.java .",
                f"javac Adapter.java MiniJson.java {class_name}.java",
                f"java Adapter cases.json {class_name}",
                "",
            ]
        ),
    )
    script.chmod(0o755)


def _write_python_public(
    public: Path, work: Path, problem: str, cases: list[dict[str, object]]
) -> None:
    if not work.is_file():
        raise ValueError(f"work file missing: {work}")
    _link_or_copy(work, public / "work.py")
    _replace_text(public / "test_public.py", render_pytest(problem, cases))
    _write_extensions(public, ["ms-python.python"])


def _write_specs(public: Path, problem: str, unlocked: int) -> Path:
    spec_dir = problem_dir(problem) / "spec"
    spec_folder = public / "spec"
    _ensure_real_session_dir(spec_folder, "spec")
    latest = spec_dir / f"level{unlocked}.md"
    if latest.is_file():
        text = latest.read_text(encoding="utf-8")
        _replace_text(public / "spec.md", text)
        _replace_text(spec_folder / "current.md", text)
    for level in range(1, unlocked + 1):
        src = spec_dir / f"level{level}.md"
        if src.is_file():
            text = src.read_text(encoding="utf-8")
            _replace_text(public / f"level{level}.md", text)
            _replace_text(spec_folder / f"level{level}.md", text)
    for extra in list(public.glob("level*.md")) + list(spec_folder.glob("level*.md")):
        try:
            n = int(extra.stem.removeprefix("level"))
        except ValueError:
            continue
        if n > unlocked:
            extra.unlink()
    return spec_folder


def _write_readme(
    public: Path,
    problem: str,
    lang: str,
    unlocked: int,
    work: Path,
    cleared: bool = False,
) -> None:
    at_end = unlocked >= max_level(problem)
    if at_end and cleared:
        vscode_task = "Replay last level"
        submit_line = (
            f"`{sys.executable} -m honepad submit {problem} --lang {lang} "
            f"--kind work` replays the last level."
        )
        confirm_line = "Replay last level. No y / n unlock."
    elif at_end:
        vscode_task = "Submit last level"
        submit_line = (
            f"`{sys.executable} -m honepad submit {problem} --lang {lang} "
            f"--kind work` submits the last level. Nothing unlocks."
        )
        confirm_line = "Submit last level. No y / n (nothing unlocks)."
    else:
        vscode_task = "Submit / Replay"
        submit_line = (
            f"`{sys.executable} -m honepad submit {problem} --lang {lang} "
            f"--kind work` unlocks the next level, or replays the last level."
        )
        confirm_line = "Submit asks y / n before unlock when a later level is still locked."
    lines = [
        f"# {problem} public tests (unlocked through L{unlocked})",
        "",
        "These are the same public traces honepad run uses (no separate hidden suite).",
        "",
        f"Current spec: spec.md and spec/current.md (L{unlocked}).",
        "Per-level copies: spec/level1.md, spec/level2.md, ...",
        "",
        f"Work file: {work}",
        f"URI: {file_uri(work)}",
        "",
        f"VS Code: Terminal > Run Task > Run public tests, or {vscode_task}.",
        f"`{sys.executable} -m honepad run {problem} --lang {lang} --kind work` does not unlock.",
        submit_line,
        confirm_line,
        "",
    ]
    if lang == "java":
        lines.extend(
            [
                "Java tests are JUnit 5 under `src/test/java/PublicTracesTest.java`.",
                "Open the Testing sidebar after the Java extension pack imports Maven.",
                "Or: `mvn test` / `./run-public.sh`.",
                "",
            ]
        )
    if lang == "python3":
        lines.extend(
            [
                "Python tests are pytest in `test_public.py`.",
                "Open the Testing sidebar after the Python extension loads.",
                "",
            ]
        )
    _replace_text(public / "README.md", "\n".join(lines))


def _write_tasks(
    public: Path, problem: str, lang: str, unlocked: int, cleared: bool = False
) -> None:
    vscode = public / ".vscode"
    _ensure_real_session_dir(vscode, "vscode")
    at_end = unlocked >= max_level(problem)
    submit_args = ["-m", "honepad", "submit", problem, "--lang", lang, "--kind", "work"]
    if not at_end:
        submit_args.extend(["--confirm", "${input:unlockConfirm}"])
    if at_end and cleared:
        submit_label = "Replay last level"
    elif at_end:
        submit_label = "Submit last level"
    else:
        submit_label = "Submit (unlock next level)"
    tasks: list[dict[str, object]] = [
        {
            "label": "Run public tests",
            "type": "shell",
            "command": sys.executable,
            "args": ["-m", "honepad", "run", problem, "--lang", lang, "--kind", "work"],
            "group": {"kind": "test", "isDefault": True},
            "presentation": {"reveal": "always", "panel": "shared"},
            "problemMatcher": [],
        },
        {
            "label": submit_label,
            "type": "shell",
            "command": sys.executable,
            "args": submit_args,
            "group": "test",
            "options": {"cwd": "${workspaceFolder:public-tests}"},
            "presentation": {"reveal": "always", "panel": "shared"},
            "problemMatcher": [],
        },
    ]
    public_cwd = "${workspaceFolder:public-tests}"
    if lang == "java":
        tasks.append(
            {
                "label": "Run JUnit tests",
                "type": "shell",
                "command": "mvn",
                "args": ["-q", "test"],
                "group": "test",
                "options": {"cwd": public_cwd},
                "problemMatcher": [],
            }
        )
        tasks.append(
            {
                "label": "Run public tests (javac)",
                "type": "shell",
                "command": f"{public_cwd}/run-public.sh",
                "group": "test",
                "options": {"cwd": public_cwd},
                "problemMatcher": [],
            }
        )
    if lang == "python3":
        tasks.append(
            {
                "label": "Run pytest",
                "type": "shell",
                "command": sys.executable,
                "args": ["-m", "pytest", "test_public.py"],
                "group": "test",
                "options": {"cwd": public_cwd},
                "problemMatcher": [],
            }
        )
    payload: dict[str, object] = {
        "version": "2.0.0",
        "tasks": tasks,
    }
    if not at_end:
        payload["inputs"] = [
            {
                "id": "unlockConfirm",
                "type": "pickString",
                "description": "Submit unlocks the next level if traces pass. Unlock?",
                "options": ["n", "y"],
                "default": "n",
            }
        ]
    _replace_text(vscode / "tasks.json", json.dumps(payload, indent=2) + "\n")
