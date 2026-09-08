# Contributing

Human contributors start here. `AGENTS.md` is for coding assistants.

## Install from a clone

The CLI finds `langs/` and `problems/` at the git root. Install from
this tree, not from a PyPI stub.

```bash
git clone https://github.com/honepad/honepad.git
cd honepad
python3 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/honepad langs
```

`python3 -m honepad` and `./honepad` also work after the editable
install. `./honepad` runs `.venv/bin/honepad`.

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

## Pull requests

Use the pull request template. Commits on `main` squash through the
required checks (`CI`, `DCO`). Keep the README as `# honepad` /
`Not ready.` Do not add topics, FUNDING, or badges.

Traces in `problems/*/cases/` are the contract. A language pack is
done when those traces pass. This tree ships public practice traces
only.

## License

Apache-2.0. See `LICENSE`.

## Conduct

See `CODE_OF_CONDUCT.md`. Security reports go to `SECURITY.md`, not
a public issue.
