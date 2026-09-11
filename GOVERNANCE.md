# Governance

## Maintainer

Sebastien Tardif (`@SebTardif`) is the sole maintainer. That account
merges to `main`, cuts tags, and publishes to PyPI.

## Decisions

Product and release calls are the maintainer's. Review comments are
welcome. They do not expand scope unless the maintainer accepts them.

## Releases

Versions live in `pyproject.toml`. release-please opens a version PR
from conventional commits on `main`. Merging that PR is a human step.
The same workflow then publishes the wheel to PyPI and attaches SLSA
provenance plus an SBOM to the GitHub Release. A hand-pushed `v*` tag
that matches the version still publishes. Do not publish from
`workflow_dispatch` on `main`.

## Conduct and security

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies to issues, pull
requests, and discussion. Vulnerabilities go through
[SECURITY.md](SECURITY.md).
