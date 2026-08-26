# Agents

Python 3.10+. Local gate before every commit:

```bash
ruff check src tests
ruff format --check src tests
python3 -m pytest
bash factory/scripts/assert-stealth.sh honepad/honepad
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
