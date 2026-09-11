# Architecture

Honepad is a local Python CLI. It replays public practice traces
against a work file on the operator's machine. It does not talk to a
remote interview service.

```text
src/honepad/
  cli.py          argv, start / run / submit / langs
  console.py      live TTY menu
  session.py      clock, unlock, work paths
  packspec.py     langs/<id>/meta.json schema
  runner.py       executes a pack recipe
  traces.py       cases JSON and compare
  workstub.py     level-sliced stubs and unlock merge
  workspace.py    VS Code folder
  term.py         color, clock, OSC 8
langs/<id>/       pack: meta.json, adapter, stubs
problems/*/cases/ public traces (the contract)
problems/*/hidden/ submit-only traces
```

A language pack is data. `meta.json` carries identity plus a `run`
recipe (`script`, `compiled`, or `hook`). `runner.py` executes the
recipe. Adding a language does not change Python.

Traces in `problems/*/cases/` are the contract. A pack is done when
those traces pass. Hidden traces run on submit after a public pass.

Local gate: `TERM=dumb PATH=.venv/bin:$PATH make check`.
