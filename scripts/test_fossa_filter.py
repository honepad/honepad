#!/usr/bin/env python3
"""Tests for scripts/fossa-filter.py."""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(__file__)
FILTER = os.path.join(HERE, "fossa-filter.py")

_spec = importlib.util.spec_from_file_location("fossa_filter", FILTER)
assert _spec and _spec.loader
fossa_filter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fossa_filter)


def run_filter(issues):
    """Run the filter on a list of FOSSA issues and return (exit, stdout)."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as handle:
        json.dump(issues, handle)
        handle.flush()
        path = handle.name
    result = subprocess.run(
        [sys.executable, FILTER, path],
        capture_output=True,
        text=True,
        check=False,
    )
    os.unlink(path)
    return result.returncode, result.stdout


def test_empty_issues():
    rc, out = run_filter([])
    assert rc == 0, f"Expected 0, got {rc}: {out}"
    assert "0 issue(s)" in out


def test_dev_pin_false_positives_filtered():
    issues = [
        {
            "revisionId": "pip+pygments$2.19.0",
            "license": "GPL-3.0-only",
            "type": "policy_flag",
        },
        {
            "revisionId": "pip+setuptools$80.0.0",
            "license": "MPL-2.0",
            "type": "policy_flag",
        },
        {
            "revisionId": "pip+ruff$0.16.6",
            "license": "GPL-2.0-only",
            "type": "policy_flag",
        },
    ]
    rc, out = run_filter(issues)
    assert rc == 0, f"Expected 0, got {rc}: {out}"
    assert "3 issue(s)" in out


def test_genuine_issue_not_filtered():
    issues = [
        {
            "revisionId": "pip+shady-crate$0.1.0",
            "license": "GPL-3.0-only",
            "type": "policy_conflict",
        },
    ]
    rc, out = run_filter(issues)
    assert rc == 1, f"Expected 1, got {rc}: {out}"
    assert "shady-crate" in out


def test_extract_package_from_revision_id():
    assert fossa_filter.extract_package({"revisionId": "pip+ruff$0.16.6"}) == "ruff"


def test_usage_exit_2():
    result = subprocess.run(
        [sys.executable, FILTER],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 2


if __name__ == "__main__":
    test_empty_issues()
    test_dev_pin_false_positives_filtered()
    test_genuine_issue_not_filtered()
    test_extract_package_from_revision_id()
    test_usage_exit_2()
    print("OK")
