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

## Roles

| Role | Who | What |
| --- | --- | --- |
| Maintainer | `@SebTardif` | Merge, release, PyPI, security advisories |
| Reviewer | anyone | Comments. Scope expands only if the maintainer accepts |

There is one maintainer. That is a known bus-factor limit. It is
documented here so it is not implicit.

## Continuity

If the maintainer is unavailable, the public tree, issues, and
[SECURITY.md](SECURITY.md) advisories stay on GitHub. There is no
second owner today. A successor would need org owner access on
`honepad` plus the PyPI trusted-publisher project. That hand-off is
a human step, not an automated transfer.

## Conduct and security

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies to issues, pull
requests, and discussion. Vulnerabilities go through
[SECURITY.md](SECURITY.md).
