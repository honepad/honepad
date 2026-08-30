# Agents

Python 3.10+. Local gate before every commit is `make check`:

```bash
ruff check src tests
ruff format --check src tests
bash factory/scripts/ensure-scala.sh
python3 -m pytest
bash factory/scripts/assert-stealth.sh honepad/honepad
bash factory/scripts/write-ledger.sh --self-test
# next-job.sh: exit 2 is success when factory/STATE.json has human_gate
```

Every commit needs `git commit -s`.

## Cwd

`git remote` must be `honepad/honepad`.

## Factory

Parent session is the outer loop. Read `factory/WORK_SOURCES.md` and run `factory/scripts/next-job.sh`. Do not ask whether to continue. One ready PR at a time. Children return only the block in `factory/CHILD_REPORT.md`.

## Stealth

Public for hosted Actions. Empty description, no topics, no FUNDING, README stays `# honepad` / `Not ready.` Do not run `/oss-announce`. See `factory/CONSTITUTION.md`.

## Methodology

Constitution + `/design` + executable tests. Spec Kit is ritual only.
Traces in `problems/*/cases/` are the contract. A language pack is done when those traces pass.
