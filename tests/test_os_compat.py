"""CLI integration on Linux, macOS, native Windows, and WSL."""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

import pytest

from honepad.cli import main
from honepad.packspec import missing_tools, run_spec
from honepad.runner import spec_src, windows_artifact
from honepad.session import load_session, work_src

# Proven on every Compat host. Other catalog runners stay Ubuntu-only.
CORE_LANGS = (
    "python3",
    "java",
    "csharp",
    "go",
    "javascript",
    "typescript",
    "cpp",
)


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


def _copy_official_work(problem: str, lang: str) -> None:
    spec = run_spec(lang)
    assert spec is not None
    src = spec_src(lang, problem, "solution", spec)
    dest = work_src(problem, lang)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)


def _skip_if_missing(lang: str) -> None:
    missing = missing_tools(lang)
    if missing:
        msg = f"{lang}: {missing[0]} not on PATH"
        if os.environ.get("CI"):
            pytest.fail(msg)
        pytest.skip(msg)


def test_skip_if_missing_fails_in_ci(monkeypatch) -> None:
    monkeypatch.setenv("CI", "true")
    monkeypatch.setattr(f"{__name__}.missing_tools", lambda _lang: ["javac"])
    with pytest.raises(pytest.fail.Exception, match="java: javac not on PATH"):
        _skip_if_missing("java")


def test_skip_if_missing_skips_without_ci(monkeypatch) -> None:
    monkeypatch.delenv("CI", raising=False)
    monkeypatch.setattr(f"{__name__}.missing_tools", lambda _lang: ["javac"])
    with pytest.raises(pytest.skip.Exception, match="java: javac not on PATH"):
        _skip_if_missing("java")


def test_compat_host_is_supported() -> None:
    kind = host_kind()
    assert kind in {"linux", "darwin", "windows", "wsl"}
    if os.environ.get("WSL_DISTRO_NAME") or Path("/proc/sys/fs/binfmt_misc/WSLInterop").exists():
        assert kind == "wsl"


def test_langs_lists_core_langs(capsys) -> None:
    assert main(["langs"]) == 0
    out = capsys.readouterr().out
    ids = {line.split()[0] for line in out.splitlines() if line.strip()}
    for lang in CORE_LANGS:
        assert lang in ids


@pytest.mark.parametrize("lang", CORE_LANGS)
def test_start_and_run_official_core_lang(lang: str, monkeypatch, tmp_path: Path, capsys) -> None:
    _skip_if_missing(lang)
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", lang, "--no-console"]) == 0
    capsys.readouterr()
    assert main(["run", "bank_system", "--kind", "solution", "--level", "1"]) == 0
    out = capsys.readouterr().out
    assert "through LEVEL 1" in out
    assert "PASS" in out


@pytest.mark.parametrize("lang", CORE_LANGS)
def test_work_submit_core_lang(lang: str, monkeypatch, tmp_path: Path, capsys) -> None:
    _skip_if_missing(lang)
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "workers", lang, "--no-console"]) == 0
    capsys.readouterr()
    _copy_official_work("workers", lang)
    assert main(["submit", "workers", "--kind", "work", "--confirm", "y"]) == 0
    out = capsys.readouterr().out
    assert "hidden through LEVEL 1" in out
    assert "UNLOCKED: level 2" in out
    assert load_session()["unlocked"] == 2


def test_windows_artifact_keeps_dotted_stem_exe(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr("honepad.runner.os.name", "nt")
    bare = tmp_path / "run.out"
    dotted_exe = tmp_path / "run.out.exe"
    wrong = tmp_path / "run.exe"
    dotted_exe.write_bytes(b"x")
    wrong.write_bytes(b"y")
    assert windows_artifact(str(bare)) == str(dotted_exe)


def test_windows_artifact_uses_exe_when_the_bare_name_is_missing(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr("honepad.runner.os.name", "nt")
    bare = tmp_path / "run"
    exe = tmp_path / "run.exe"
    exe.write_text("x", encoding="utf-8")
    assert windows_artifact(str(bare)) == str(exe)


def test_windows_artifact_keeps_an_existing_bare_file(tmp_path: Path) -> None:
    bare = tmp_path / "run"
    bare.write_text("x", encoding="utf-8")
    assert windows_artifact(str(bare)) == str(bare)


def test_windows_artifact_keeps_existing_exe(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr("honepad.runner.os.name", "nt")
    exe = tmp_path / "run.exe"
    exe.write_bytes(b"x")
    assert windows_artifact(str(exe)) == str(exe)


def test_windows_artifact_returns_original_when_neither_exists(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr("honepad.runner.os.name", "nt")
    bare = tmp_path / "run"
    assert windows_artifact(str(bare)) == str(bare)


def test_windows_artifact_rewrites_when_os_name_is_nt(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr("honepad.runner.os.name", "nt")
    bare = tmp_path / "honepadrun"
    exe = tmp_path / "honepadrun.exe"
    exe.write_bytes(b"x")
    assert windows_artifact(str(bare)) == str(exe)
