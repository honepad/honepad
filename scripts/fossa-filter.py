#!/usr/bin/env python3
"""Filter known false positives from FOSSA test JSON output.

Exit 0 if all issues are documented false positives or there are none.
Exit 1 if any genuine issues remain after filtering.
Exit 2 on usage error.
"""

from __future__ import annotations

import json
import sys

# honepad has no runtime third-party deps. These hits are discovered
# text inside dev pins (pytest/ruff/build), not declared product
# licenses. Pygments is BSD-2-Clause; setuptools is MIT; ruff is MIT.
KNOWN_FALSE_POSITIVES: dict[str, set[str]] = {
    "pygments": {
        "LGPL-2.1-or-later",
        "LGPL-2.1-only",
        "LGPL-3.0-only",
        "GPL-3.0-only",
        "GPL-3.0-or-later",
        "GPL-2.0-or-later",
        "GPL-2.0-only",
        "GPL-2.0-with-autoconf-exception",
        "MPL-2.0",
        "MPL-1.1",
        "CPL-1.0",
        "gpl-2.0-plus WITH guile-exception-2.0",
        "lgpl-2.1 WITH qt-lgpl-exception-1.1",
    },
    "setuptools": {
        "LGPL-3.0-or-later",
        "LGPL-3.0-only",
        "MPL-2.0",
    },
    "ruff": {
        "GPL-2.0-only",
    },
}


def extract_package(issue: dict) -> str:
    """Extract the package name from a FOSSA issue.

    FOSSA uses 'revisionId' with format 'pip+ruff$0.16.6'.
    """
    rev = issue.get("revisionId", "")
    if rev:
        if "+" in rev:
            rev = rev.split("+", 1)[1]
        if "$" in rev:
            rev = rev.rsplit("$", 1)[0]
        return rev
    return issue.get("package", "") or issue.get("name", "") or ""


def is_false_positive(pkg: str, license_id: str, issue_type: str = "") -> bool:
    """Return True if the (package, license) tuple is a documented FP."""
    del issue_type
    allowed = KNOWN_FALSE_POSITIVES.get(pkg)
    if not allowed:
        return False
    return license_id in allowed


def load_issues(path: str) -> list[dict]:
    with open(path) as handle:
        raw = handle.read().strip()
    if not raw:
        return []
    data = json.loads(raw)
    if isinstance(data, list):
        issues = data
    else:
        issues = data.get("issues", data.get("issue", []))
    if not isinstance(issues, list):
        return []
    return issues


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: fossa-filter.py <fossa-results.json>", file=sys.stderr)
        return 2

    try:
        issues = load_issues(sys.argv[1])
    except json.JSONDecodeError:
        print("FAIL: FOSSA JSON was empty or unparseable.", file=sys.stderr)
        return 1

    real_issues = []
    filtered_count = 0
    for issue in issues:
        pkg = extract_package(issue)
        lic = issue.get("license", "") or issue.get("licenseId", "") or ""
        itype = issue.get("type", "") or issue.get("issueType", "") or ""
        if is_false_positive(pkg, lic, itype):
            filtered_count += 1
            continue
        real_issues.append(issue)

    if real_issues:
        print(
            f"FAIL: {len(real_issues)} genuine issue(s) after filtering "
            f"{filtered_count} known false positives:"
        )
        for row in real_issues:
            pkg = extract_package(row)
            lic = row.get("license", "") or row.get("licenseId", "?")
            itype = row.get("type", "") or row.get("issueType", "?")
            print(f"  - {pkg}  {lic}  ({itype})")
        return 1

    print(f"OK: All {filtered_count} issue(s) are documented false positives.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
