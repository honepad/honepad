# Agents

Python 3.10+. Local gate before every commit is `make check`:

```bash
ruff check src tests
ruff format --check src tests
bash factory/scripts/ensure-scala.sh
python3 -m pytest
bash factory/scripts/assert-stealth.sh honepad/honepad
bash factory/scripts/write-ledger.sh --self-test
python3 -c 'import json, subprocess, sys; state = json.load(open("factory/STATE.json")); result = subprocess.run(["bash", "factory/scripts/next-job.sh"], check=False); sys.exit(0 if result.returncode == 2 else 1) if state.get("human_gate") else sys.exit(0 if result.returncode == 0 else 1)'
```

Every commit needs `git commit -s`.

## Cwd

`git remote` must be `honepad/honepad`.

## Factory

Parent session is the outer loop. Read `factory/WORK_SOURCES.md` and run `factory/scripts/next-job.sh`. Do not ask whether to continue. One ready PR at a time. Children return only the block in `factory/CHILD_REPORT.md`.

## Stealth

Public for hosted Actions. Empty description, no topics, no FUNDING, README stays `# honepad` / `Not ready.` Do not run `/oss-announce`. See `factory/CONSTITUTION.md`.

## Language packs

A pack is a directory: `langs/<id>/meta.json` (identity plus a `run` recipe), an adapter, and
`problems/*/{solution,stub}.<ext>`. `honepad.runner` executes the recipe, so adding a language
touches no Python. Schema and worked examples: `langs/ADDING-A-LANGUAGE.md`.

## Methodology

Constitution + `/design` + executable tests. Spec Kit is ritual only.
Traces in `problems/*/cases/` are the contract. A language pack is done when those traces pass.
