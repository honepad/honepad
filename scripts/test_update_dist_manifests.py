#!/usr/bin/env python3
"""Tests for Homebrew formula and Scoop manifest generators."""

from __future__ import annotations

import importlib.util
import os
import tempfile

HERE = os.path.dirname(__file__)


def _load(name: str, filename: str):
    path = os.path.join(HERE, filename)
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


brew = _load("update_homebrew_formula", "update-homebrew-formula.py")
scoop = _load("update_scoop_manifest", "update-scoop-manifest.py")
SHA = "d099e4eaa35134b451ff8eb7fd93ce841cd8b81d6537dacbb7f5d758ad97244b"


def test_homebrew_strips_v_and_embeds_sha():
    body = brew.render("v0.1.0", SHA)
    assert "honepad-0.1.0.tar.gz" in body
    assert SHA in body
    assert "v0.1.0" in body


def test_scoop_wheel_url_and_hash():
    body = scoop.render("0.1.0", SHA)
    assert "honepad-0.1.0-py3-none-any.whl" in body
    assert f"sha256:{SHA}" in body
    assert '"depends": "python"' in body


def test_bad_sha_exits():
    try:
        brew.render("0.1.0", "nope")
    except SystemExit:
        pass
    else:
        raise AssertionError("expected SystemExit")


def test_check_mode_detects_stale():
    import sys

    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "honepad.rb")
        with open(path, "w") as handle:
            handle.write("stale\n")
        old = sys.argv
        sys.argv = [
            "update-homebrew-formula.py",
            "--version",
            "0.1.0",
            "--sha256",
            SHA,
            "--output",
            path,
            "--check",
        ]
        try:
            code = brew.main()
        finally:
            sys.argv = old
        assert code == 1


if __name__ == "__main__":
    test_homebrew_strips_v_and_embeds_sha()
    test_scoop_wheel_url_and_hash()
    test_bad_sha_exits()
    test_check_mode_detects_stale()
    print("OK")
