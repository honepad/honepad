"""CLI integration on Linux, macOS, native Windows, and WSL."""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

from honepad.catalog import repo_root
from honepad.cli import main
from honepad.session import load_session, work_src


def host_kind() -> str:
    if sys.platform == "darwin":
        return "darwin"
    if sys.platform.startswith("win"):
        return "windows"
    if os.environ.get("WSL_DISTRO_NAME") or Path("/proc/sys/fs/binfmt_misc/WSLInterop").exists():
        return "wsl"
    if sys.platform.startswith("linux"):
        return "linux"
    return sys.platform


def _copy_official_python_work(problem: str) -> None:
    src = repo_root() / "langs" / "python3" / "problems" / problem / "solution.py"
    dest = work_src(problem, "python3")
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)


def test_compat_host_is_supported() -> None:
    assert host_kind() in {"linux", "darwin", "windows", "wsl"}


def test_langs_lists_python3(capsys) -> None:
    assert main(["langs"]) == 0
    out = capsys.readouterr().out
    assert "python3" in out


def test_start_and_run_official_python3(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--no-console"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution", "--level", "1"]) == 0
    out = capsys.readouterr().out
    assert "through LEVEL 1" in out
    assert "PASS" in out


def test_work_submit_runs_hidden(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", "python3", "--no-console"]) == 0
    capsys.readouterr()
    _copy_official_python_work("workers")
    assert main(["submit", "workers", "--kind", "work", "--confirm", "y"]) == 0
    out = capsys.readouterr().out
    assert "hidden through LEVEL 1" in out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2
