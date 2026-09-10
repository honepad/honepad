"""Copy langs/ and problems/ into the package so a wheel can run the CLI."""

from __future__ import annotations

import shutil
from pathlib import Path

from setuptools import setup
from setuptools.command.build_py import build_py
from setuptools.command.sdist import sdist

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "src" / "honepad" / "_data"


def copy_data() -> None:
    """Copy checkout trees, or keep bundled copies when building from an sdist."""
    DATA.mkdir(parents=True, exist_ok=True)
    for name in ("langs", "problems"):
        src = ROOT / name
        dest = DATA / name
        if not src.is_dir():
            if dest.is_dir():
                continue
            raise FileNotFoundError(src)
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(
            src,
            dest,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store"),
        )


class BuildPy(build_py):
    def run(self) -> None:
        copy_data()
        super().run()


class Sdist(sdist):
    def run(self) -> None:
        copy_data()
        super().run()


setup(cmdclass={"build_py": BuildPy, "sdist": Sdist})
