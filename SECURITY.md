# Security

Report vulnerabilities privately through GitHub Security Advisories:

https://github.com/honepad/honepad/security/advisories/new

Do not open a public issue for a security report.

We aim to acknowledge a report within 7 days. Include enough detail
to reproduce the issue (version or commit, steps, and impact).

## Design notes

Honepad is a local CLI. It runs practice traces from this tree against
a work file on the operator's machine. It does not talk to a remote
interview service and it does not ship live interview items.

## Assurance case

| Threat | Control | Where |
| --- | --- | --- |
| Public practice only | Traces live under `problems/*/cases/`. No live items. | this tree |
| Hostile work file | Fail closed. No pack-solution fallback. Timeouts. | `runner.py`, adapters |
| Session path escape | Refuse work/session/workspace symlinks outside the session | `session.py` |
| Fake pass report | Adapters sink stdout; report must match case count | adapters, `_pyrun.py` |
| Reports stay private | GitHub Security Advisories, not public issues | this file |
| Supply chain | Dependabot, CodeQL, Scorecard, secret scanning | `.github/workflows/` |
| Release tamper | SLSA provenance, CycloneDX SBOM, signed release assets | GitHub Releases |
| C parser bugs | ClusterFuzzLite on `langs/c/minijson` (30s, not required) | `.clusterfuzzlite/` |

Credit in a release note or advisory when a reporter wants it. See
[CHANGELOG.md](CHANGELOG.md).


## Verifying a GitHub Release

Each `v*` GitHub Release should include the wheel, the sdist, a
CycloneDX SBOM, and SLSA provenance (`.intoto.jsonl`). After
downloading an artifact:

```bash
gh attestation verify honepad-0.1.0-py3-none-any.whl \
  --repo honepad/honepad
```

PyPI installs use Trusted Publishing. GitHub Release assets are the
signed copies you can check locally.
