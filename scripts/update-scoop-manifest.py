#!/usr/bin/env python3
"""Rewrite bucket/honepad.json for a GitHub Release wheel."""

from __future__ import annotations

import argparse
import json
import sys


def render(version: str, sha256: str) -> str:
    if version.startswith("v"):
        version = version[1:]
    if len(sha256) != 64 or any(c not in "0123456789abcdef" for c in sha256.lower()):
        raise SystemExit("sha256 must be 64 hex characters")
    data = {
        "version": version,
        "description": "Local CLI for public practice problems",
        "homepage": "https://github.com/honepad/honepad",
        "license": "Apache-2.0",
        "depends": "python",
        "url": (
            "https://github.com/honepad/honepad/releases/download/"
            f"v{version}/honepad-{version}-py3-none-any.whl#/honepad.whl"
        ),
        "hash": f"sha256:{sha256.lower()}",
        "installer": {
            "script": [
                (
                    "python -m pip install --disable-pip-version-check "
                    '--no-warn-script-location --target "$dir" "$dir\\honepad.whl"'
                )
            ]
        },
        "bin": [["Scripts\\honepad.exe", "honepad"]],
        "checkver": {"github": "https://github.com/honepad/honepad"},
        "autoupdate": {
            "url": (
                "https://github.com/honepad/honepad/releases/download/"
                "v$version/honepad-$version-py3-none-any.whl#/honepad.whl"
            )
        },
    }
    return json.dumps(data, indent=4) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    body = render(args.version, args.sha256)
    if args.check:
        with open(args.output) as handle:
            current = handle.read()
        if current != body:
            print(f"STALE: {args.output}", file=sys.stderr)
            return 1
        print("OK: manifest is current")
        return 0
    with open(args.output, "w") as handle:
        handle.write(body)
    print(f"OK: wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
