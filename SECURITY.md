# Security

Report vulnerabilities privately through GitHub Security Advisories:

https://github.com/honepad/honepad/security/advisories/new

Do not open a public issue for a security report.

We aim to acknowledge a report within 7 days. Include enough detail
to reproduce the issue (version or commit, steps, and impact).

## Design notes

honepad is a local CLI. It runs practice traces from this tree against
a work file on the operator's machine. It does not talk to a remote
interview service and it does not ship live interview items.

| Claim | How we check it |
| --- | --- |
| Public practice only | Traces live under `problems/*/cases/`. No live items. |
| Reports stay private | GitHub Security Advisories, not public issues |
| Supply chain | Dependabot, CodeQL, Scorecard, secret scanning |
