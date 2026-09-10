"""Wheel and sdist must ship langs/ and problems/."""

from __future__ import annotations

import zipfile
from pathlib import Path

from honepad.catalog import resolve_repo_root


def test_resolve_repo_root_prefers_env(tmp_path: Path) -> None:
    assert resolve_repo_root(Path("/unused/src/honepad/catalog.py"), str(tmp_path)) == tmp_path


def test_resolve_repo_root_checkout_when_langs_exist(tmp_path: Path) -> None:
    checkout = tmp_path / "honepad"
    module = checkout / "src" / "honepad" / "catalog.py"
    module.parent.mkdir(parents=True)
    (checkout / "langs").mkdir()
    (checkout / "langs" / "catalog.json").write_text("{}\n", encoding="utf-8")
    assert resolve_repo_root(module, None) == checkout


def test_resolve_repo_root_bundled_data(tmp_path: Path) -> None:
    pkg = tmp_path / "site-packages" / "honepad"
    module = pkg / "catalog.py"
    data = pkg / "_data" / "langs"
    data.mkdir(parents=True)
    (data / "catalog.json").write_text("{}\n", encoding="utf-8")
    assert resolve_repo_root(module, None) == pkg / "_data"


def test_wheel_includes_langs_and_problems(tmp_path: Path) -> None:
    import subprocess
    import sys

    root = Path(__file__).resolve().parents[1]
    dest = tmp_path / "dist"
    dest.mkdir()
    subprocess.run(
        [sys.executable, "-m", "pip", "wheel", str(root), "-w", str(dest), "--no-deps"],
        check=True,
        cwd=root,
    )
    wheels = list(dest.glob("honepad-*.whl"))
    assert len(wheels) == 1
    with zipfile.ZipFile(wheels[0]) as archive:
        names = archive.namelist()
    assert any(name.endswith("honepad/_data/langs/catalog.json") for name in names)
    hidden = (
        "honepad/_data/problems/workers/hidden/level1.json",
        "honepad/_data/problems/bank_system/hidden/level4.json",
    )
    for suffix in hidden:
        assert any(name.endswith(suffix) for name in names)
