# Contributing

Human contributors start here. `AGENTS.md` is for coding assistants.

## Where to start

Pick an open issue labeled
[good first issue](https://github.com/honepad/honepad/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
or
[help wanted](https://github.com/honepad/honepad/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22).
File a bug or a feature request with the issue templates. Questions
that are not bugs can be a plain issue. See [SUPPORT.md](SUPPORT.md).

## Install from a clone

A checkout keeps `langs/` and `problems/` at the git root. A wheel or
sdist copies those trees into the package (`honepad/_data`). The CLI
looks at `HONEPAD_ROOT`, then the checkout, then the bundled copy.

```bash
git clone https://github.com/honepad/honepad.git
cd honepad
python3 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/honepad langs
```

`python3 -m honepad` and `./honepad` also work after the editable
install. `./honepad` runs `.venv/bin/honepad`. `pip install honepad`
is the same CLI once the published wheel includes the data trees.

## Local gate

The commands in `AGENTS.md` must pass before you open a pull request.
Put the venv on `PATH` and use a dumb terminal so color escapes do not
break string asserts:

```bash
TERM=dumb PATH=.venv/bin:$PATH make check
```

Every commit needs a Developer Certificate of Origin trailer:

```bash
git commit -s
```

The sign-off email is `git config user.email`. The DCO workflow skips
bot commits and merge commits.

## Coding standards

- Python 3.10+. Format and lint with ruff (`ruff check`, `ruff format`).
- New behavior needs a test in the same change. Traces in
  `problems/*/cases/` are the contract for a language pack.
- Do not add a language by editing Python. Add `langs/<id>/meta.json`,
  an adapter, and stubs. See [langs/ADDING-A-LANGUAGE.md](langs/ADDING-A-LANGUAGE.md).
- Public copy: "practice problems", not "traces". No interview-vendor
  affiliation.

## Language packs

New language packs are proven on Ubuntu CI. All-platform means the
ids in `CORE_LANGS` in [tests/test_os_compat.py](tests/test_os_compat.py)
plus the Compat job.

## Pull requests

Use the pull request template. Commits on `main` squash through the
required check `CI`. DCO is enforced by workflow, not as a required
check. Start with [README.md](README.md).


Traces in `problems/*/cases/` are the contract. A language pack is
done when those traces pass. This tree ships public practice traces
only.

## License

Apache-2.0. See `LICENSE`.

## Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Security reports go to
[SECURITY.md](SECURITY.md), not a public issue. How the project is
run is in [GOVERNANCE.md](GOVERNANCE.md).
