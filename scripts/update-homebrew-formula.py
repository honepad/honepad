#!/usr/bin/env python3
"""Rewrite Formula/honepad.rb for a GitHub Release sdist."""

from __future__ import annotations

import argparse
import sys

TEMPLATE = """\
class Honepad < Formula
  include Language::Python::Virtualenv

  desc "Local CLI for public practice problems"
  homepage "https://github.com/honepad/honepad"
  url "https://github.com/honepad/honepad/releases/download/v{version}/honepad-{version}.tar.gz"
  sha256 "{sha256}"
  license "Apache-2.0"

  depends_on "python@3.13"

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "languages", shell_output("#{{bin}}/honepad langs")
  end
end
"""


def render(version: str, sha256: str) -> str:
    if version.startswith("v"):
        version = version[1:]
    if len(sha256) != 64 or any(c not in "0123456789abcdef" for c in sha256.lower()):
        raise SystemExit("sha256 must be 64 hex characters")
    return TEMPLATE.format(version=version, sha256=sha256.lower())


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
        print("OK: formula is current")
        return 0
    with open(args.output, "w") as handle:
        handle.write(body)
    print(f"OK: wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
