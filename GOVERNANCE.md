# Governance

## Maintainer

Sebastien Tardif (`@SebTardif`) is the sole maintainer. That account
merges to `main`, cuts tags, and publishes to PyPI.

## Decisions

Product and release calls are the maintainer's. Review comments are
welcome. They do not expand scope unless the maintainer accepts them.

## Releases

Versions live in `pyproject.toml`. A GitHub Release and a PyPI upload
happen from a `v*` tag that matches that version. There is no
release-please bot. Do not publish from `workflow_dispatch` on `main`.

## Conduct and security

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies to issues, pull
requests, and discussion. Vulnerabilities go through
[SECURITY.md](SECURITY.md).
